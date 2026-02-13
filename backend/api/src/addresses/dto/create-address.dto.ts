import {
  IsBoolean,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPhoneNumber,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateAddressDto {
  @IsOptional()
  @IsString()
  @MaxLength(50)
  label?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  receiverName!: string;

  // ถ้าจะไม่ strict เบอร์ไทย ใช้ IsString ก็ได้
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  phone!: string;

  @IsString()
  @IsNotEmpty()
  addressLine1!: string;

  @IsOptional()
  @IsString()
  addressLine2?: string;

  @IsString()
  @IsNotEmpty()
  province!: string;

  @IsString()
  @IsNotEmpty()
  district!: string;

  @IsString()
  @IsNotEmpty()
  subdistrict!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(10)
  postcode!: string;

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