import { IsEnum, IsISO8601, IsObject, IsOptional, IsString, MaxLength } from 'class-validator';
import { ShipmentStatus } from '@prisma/client';

export class TransitionShipmentLegDto {
  @IsEnum(ShipmentStatus)
  status: ShipmentStatus;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  note?: string;

  // สำหรับ FLIGHT (optional)
  @IsOptional()
  @IsString()
  @MaxLength(20)
  flightNo?: string;

  @IsOptional()
  @IsISO8601()
  departAt?: string; // ISO string

  @IsOptional()
  @IsISO8601()
  arriveAt?: string; // ISO string

  @IsOptional()
  @IsObject()
  meta?: any;
}