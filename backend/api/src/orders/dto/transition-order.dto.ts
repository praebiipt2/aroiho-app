import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export const ORDER_STATUSES = [
  'CONFIRMED',
  'PREPARING',
  'SHIPPED',
  'DELIVERED',
  'CANCELLED',
] as const;

export type OrderStatus = (typeof ORDER_STATUSES)[number];

export class TransitionOrderDto {
  @IsIn(ORDER_STATUSES)
  to: OrderStatus;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}