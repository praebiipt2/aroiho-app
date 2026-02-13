import { IsUUID, IsNumber, Min } from 'class-validator';

export class AddCartItemDto {
  @IsUUID()
  productId: string;

  @IsUUID()
  inventoryLotId: string;

  @IsNumber()
  @Min(0.001)
  quantity: number;
}