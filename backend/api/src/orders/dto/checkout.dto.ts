import { IsEnum, IsNumber, IsOptional, IsUUID, Min } from 'class-validator';
import { ShippingMethod } from '@prisma/client';

export class CheckoutDto {
  @IsUUID()
  addressId: string;

  @IsOptional()
  @IsEnum(ShippingMethod)
  shippingMethod?: ShippingMethod; // AUTO | GROUND | AIR

  @IsOptional()
  @IsNumber()
  @Min(0)
  shippingSurcharge?: number;
}
