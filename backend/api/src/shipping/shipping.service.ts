import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ShipmentStatus, TrackingEventType, TransportMode } from '@prisma/client';
import { TransitionShipmentLegDto } from './dto/transition-leg.dto';

type Actor = { id?: string; sub?: string; role?: string };

@Injectable()
export class ShippingService {
  constructor(private readonly prisma: PrismaService) {}

  // ====== PUBLIC: Customer ดู shipment ของออเดอร์ตัวเอง ======
  async getMyShipment(userId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, userId },
      select: { id: true },
    });
    if (!order) throw new NotFoundException('Order not found');

    const shipment = await this.prisma.shipment.findUnique({
      where: { orderId },
      include: { legs: { orderBy: { seq: 'asc' } } },
    });

    if (!shipment) throw new NotFoundException('Shipment not found');
    return shipment;
  }

  // ====== ADMIN/RIDER: อัปเดต shipment leg ======
  async transitionLeg(orderId: string, legId: string, dto: TransitionShipmentLegDto, actor?: Actor) {
    return this.prisma.$transaction(async (tx) => {
      // 1) ต้องมี shipment ของ order
      const shipment = await tx.shipment.findUnique({
        where: { orderId },
        include: { legs: true },
      });
      if (!shipment) throw new NotFoundException('Shipment not found');

      // 2) ต้องเป็น leg ของ shipment นี้
      const leg = shipment.legs.find((l) => l.id === legId);
      if (!leg) throw new NotFoundException('Shipment leg not found');

      // 3) validate flight fields (เฉพาะ leg แบบ FLIGHT)
      const hasFlightFields = !!(dto.flightNo || dto.departAt || dto.arriveAt);
      if (leg.mode !== TransportMode.FLIGHT && hasFlightFields) {
        throw new BadRequestException('flightNo/departAt/arriveAt allowed only for FLIGHT leg');
      }

      const departAt = dto.departAt ? new Date(dto.departAt) : undefined;
      const arriveAt = dto.arriveAt ? new Date(dto.arriveAt) : undefined;

      if (departAt && isNaN(departAt.getTime())) throw new BadRequestException('departAt invalid');
      if (arriveAt && isNaN(arriveAt.getTime())) throw new BadRequestException('arriveAt invalid');
      if (departAt && arriveAt && arriveAt.getTime() < departAt.getTime()) {
        throw new BadRequestException('arriveAt must be after departAt');
      }

      // 4) idempotent 
      const statusSame = leg.status === dto.status;

      const flightSame =
        (leg.flightNo ?? null) === (dto.flightNo ?? null) &&
        (leg.departAt?.toISOString() ?? null) === (departAt?.toISOString() ?? null) &&
        (leg.arriveAt?.toISOString() ?? null) === (arriveAt?.toISOString() ?? null);

      const metaSame = JSON.stringify(leg.meta ?? null) === JSON.stringify(dto.meta ?? null);

      if (statusSame && flightSame && metaSame && !dto.note) {
        return {
          shipmentId: shipment.id,
          shipmentStatus: shipment.status,
          updatedLeg: leg,
          idempotent: true,
        };
      }

      // 5) update leg
      const updatedLeg = await tx.shipmentLeg.update({
        where: { id: legId },
        data: {
          status: dto.status,
          flightNo: dto.flightNo ?? undefined,
          departAt: departAt ?? undefined,
          arriveAt: arriveAt ?? undefined,
          meta: dto.meta ?? undefined,
        },
      });

      // 6) คำนวณ shipment.status ใหม่จาก legs ทั้งหมด (แทนค่า leg ที่แก้)
      const nextLegs = shipment.legs.map((l) => (l.id === legId ? { ...l, ...updatedLeg } : l));
      const newOverall = this.computeOverallStatus(nextLegs);

      await tx.shipment.update({
        where: { id: shipment.id },
        data: { status: newOverall },
      });

      // 7) auto sync order status (ถ้าต้องการ)
      await this.syncOrderStatusByShipment(tx, orderId, newOverall);

      // 8) tracking event (เมื่อ status เปลี่ยนจริง)
      if (!statusSame) {
        const trackingType = this.mapToTracking(dto.status);
        if (trackingType) {
          await tx.trackingEvent.create({
            data: {
              orderId,
              type: trackingType,
              message: dto.note ?? this.defaultMessage(trackingType),
              meta: {
                shipmentId: shipment.id,
                legId: updatedLeg.id,
                seq: updatedLeg.seq,
                mode: updatedLeg.mode,
                fromStatus: leg.status,
                toStatus: updatedLeg.status,
                flightNo: updatedLeg.flightNo,
                departAt: updatedLeg.departAt,
                arriveAt: updatedLeg.arriveAt,
                actor: {
                  userId: actor?.id ?? actor?.sub ?? null,
                  role: actor?.role ?? null,
                },
                ...(dto.meta ? { extra: dto.meta } : {}),
              },
            },
          });
        } else if (dto.status === ShipmentStatus.FAILED) {
          await tx.trackingEvent.create({
            data: {
              orderId,
              type: TrackingEventType.NOTE,
              message: dto.note ?? 'การจัดส่งมีปัญหา',
              meta: {
                shipmentId: shipment.id,
                legId: updatedLeg.id,
                seq: updatedLeg.seq,
                mode: updatedLeg.mode,
                fromStatus: leg.status,
                toStatus: updatedLeg.status,
                actor: {
                  userId: actor?.id ?? actor?.sub ?? null,
                  role: actor?.role ?? null,
                },
                ...(dto.meta ? { extra: dto.meta } : {}),
              },
            },
          });
        }
      }

      // 9) ถ้าเป็น FLIGHT แล้วอัปเดต flightNo/เวลา (แต่ status ไม่เปลี่ยน) → NOTE
      const flightChanged = leg.mode === TransportMode.FLIGHT && !flightSame;
      if (flightChanged) {
        await tx.trackingEvent.create({
          data: {
            orderId,
            type: TrackingEventType.NOTE,
            message: dto.note ?? 'อัปเดตข้อมูลเที่ยวบิน',
            meta: {
              shipmentId: shipment.id,
              legId: updatedLeg.id,
              seq: updatedLeg.seq,
              mode: updatedLeg.mode,
              flightNo: updatedLeg.flightNo,
              departAt: updatedLeg.departAt,
              arriveAt: updatedLeg.arriveAt,
              actor: {
                userId: actor?.id ?? actor?.sub ?? null,
                role: actor?.role ?? null,
              },
            },
          },
        });
      }

      return {
        shipmentId: shipment.id,
        shipmentStatus: newOverall,
        updatedLeg,
        idempotent: false,
      };
    });
  }

  private statusRank(s: ShipmentStatus) {
    const rank: Record<ShipmentStatus, number> = {
      PLANNED: 0,
      PICKED_UP: 1,
      IN_TRANSIT: 2,
      OUT_FOR_DELIVERY: 3,
      DELIVERED: 4,
      FAILED: 99,
    };
    return rank[s] ?? 0;
  }

  private computeOverallStatus(legs: Array<{ status: ShipmentStatus }>) {
    if (legs.some((l) => l.status === ShipmentStatus.FAILED)) return ShipmentStatus.FAILED;

    return legs.reduce((acc, l) => {
      return this.statusRank(l.status) > this.statusRank(acc) ? l.status : acc;
    }, ShipmentStatus.PLANNED);
  }

  private mapToTracking(status: ShipmentStatus) {
    const map: Partial<Record<ShipmentStatus, TrackingEventType>> = {
      PICKED_UP: TrackingEventType.PICKED_UP,
      IN_TRANSIT: TrackingEventType.IN_TRANSIT,
      OUT_FOR_DELIVERY: TrackingEventType.OUT_FOR_DELIVERY,
      DELIVERED: TrackingEventType.DELIVERED,
    };
    return map[status];
  }

  private defaultMessage(type: TrackingEventType) {
    switch (type) {
      case TrackingEventType.PICKED_UP:
        return 'รับสินค้าแล้ว';
      case TrackingEventType.IN_TRANSIT:
        return 'กำลังขนส่ง';
      case TrackingEventType.OUT_FOR_DELIVERY:
        return 'กำลังนำส่ง';
      case TrackingEventType.DELIVERED:
        return 'จัดส่งสำเร็จ';
      default:
        return '';
    }
  }

  private async syncOrderStatusByShipment(tx: any, orderId: string, overall: ShipmentStatus) {

    if (
      overall === ShipmentStatus.PICKED_UP ||
      overall === ShipmentStatus.IN_TRANSIT ||
      overall === ShipmentStatus.OUT_FOR_DELIVERY
    ) {
      await tx.order.update({ where: { id: orderId }, data: { orderStatus: 'SHIPPED' } });
      return;
    }

    if (overall === ShipmentStatus.DELIVERED) {
      await tx.order.update({ where: { id: orderId }, data: { orderStatus: 'DELIVERED' } });

      // กัน duplicate DELIVERED event (เผื่อ flow อื่นสร้างไปแล้ว)
      const exists = await tx.trackingEvent.findFirst({
        where: { orderId, type: TrackingEventType.DELIVERED },
      });

      if (!exists) {
        await tx.trackingEvent.create({
          data: { orderId, type: TrackingEventType.DELIVERED, message: 'จัดส่งสำเร็จ' },
        });
      }
    }
  }
}