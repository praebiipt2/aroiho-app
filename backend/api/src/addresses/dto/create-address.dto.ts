import { IsBoolean, IsNumber, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateAddressDto {
  @IsString()
  @MaxLength(50)
  label: string; // เช่น บ้าน/ที่ทำงาน

  @IsString()
  @MaxLength(100)
  receiverName: string;

  @IsString()
  @MaxLength(20)
  phone: string;

  @IsString()
  @MaxLength(255)
  addressLine1: string;

  @IsOptional()
  @IsString()
  @MaxLength(255)
  addressLine2?: string;

  @IsString()
  @MaxLength(100)
  province: string;

  @IsString()
  @MaxLength(100)
  district: string;

  @IsString()
  @MaxLength(100)
  subdistrict: string;

  @IsString()
  @MaxLength(10)
  postcode: string;

  @IsOptional()
  @IsNumber()
  lat?: number;

  @IsOptional()
  @IsNumber()
  lng?: number;

  @IsOptional()
  @IsBoolean()
  isDefault?: boolean;
}