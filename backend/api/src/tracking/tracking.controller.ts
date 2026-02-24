import { Body, Controller, Get, Param, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { TrackingService } from './tracking.service';
import { IsEnum, IsObject, IsOptional, IsString, MaxLength } from 'class-validator';
import { TrackingEventType } from '@prisma/client';

class AddTrackingEventDto {
  @IsEnum(TrackingEventType)
  type: TrackingEventType;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  message?: string;

  @IsOptional()
  @IsObject()
  meta?: any;
}

@UseGuards(AuthGuard('jwt'))
@Controller('v1')
export class TrackingController {
  constructor(private readonly trackingService: TrackingService) {}

  // ลูกค้าเรียกดู tracking ของออเดอร์ตัวเอง
  @Get('orders/:orderId/tracking')
  getMyOrderTracking(@Req() req: any, @Param('orderId') orderId: string) {
    const userId = req.user.id ?? req.user.sub;
    return this.trackingService.getMyOrderTracking(userId, orderId);
  }

  // DEV: ยัด event เองได้ เพื่อเทสต์ timeline
  @Post('orders/:orderId/tracking-events')
  addTrackingEvent(@Req() req: any, @Param('orderId') orderId: string, @Body() dto: AddTrackingEventDto) {
    const userId = req.user.id ?? req.user.sub;
    return this.trackingService.addEventForMyOrder(userId, orderId, dto);
  }
}