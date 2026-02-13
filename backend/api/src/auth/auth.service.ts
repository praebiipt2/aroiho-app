import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { randomUUID } from 'crypto';

@Injectable()
export class AuthService {
  constructor(private prisma: PrismaService, private jwt: JwtService) {}

  async requestOtp(phone: string) {
    return { success: true, phone, requestId: randomUUID(), otp: '123456' };
  }

  async verifyOtp(phone: string, otp: string, requestId: string) {
    if (otp !== '123456') throw new UnauthorizedException('Invalid OTP');

    const user = await this.prisma.user.upsert({
      where: { phone },
      update: {},
      create: { phone, role: 'CUSTOMER', status: 'ACTIVE' },
    });

    const accessToken = this.jwt.sign(
      { sub: user.id, phone: user.phone ?? undefined, role: user.role },
      { secret: process.env.JWT_ACCESS_SECRET, expiresIn: 900 }, // 15 นาที
    );

    const refreshToken = this.jwt.sign(
      { sub: user.id },
      { secret: process.env.JWT_REFRESH_SECRET, expiresIn: 604800 }, // 7 วัน
    );

    return {
      accessToken,
      refreshToken,
      user: { id: user.id, phone: user.phone, role: user.role },
    };
  }

  // ✅ ต้องอยู่นอก verifyOtp
  async getMe(userId: string) {
    return this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        phone: true,
        email: true,
        displayName: true,
        role: true,
        status: true,
      },
    });
  }
}