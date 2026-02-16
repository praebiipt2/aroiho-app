import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { randomUUID } from 'crypto';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async requestOtp(phone: string) {
    return { success: true, phone, requestId: randomUUID(), otp: '123456' };
  }

  async verifyOtp(phone: string, otp: string, requestId: string) {
    if (otp !== '123456') throw new UnauthorizedException('Invalid OTP');
    void requestId;

    const user = await this.prisma.user.upsert({
      where: { phone },
      update: {},
      create: { phone, role: 'CUSTOMER', status: 'ACTIVE' },
    });

    // ✅ ใช้ ConfigService + มี fallback กันพัง
    const accessSecret =
      this.config.get<string>('JWT_ACCESS_SECRET') ?? 'dev-access-secret';
    const refreshSecret =
      this.config.get<string>('JWT_REFRESH_SECRET') ?? 'dev-refresh-secret';

    const accessToken = this.jwt.sign(
      { sub: user.id, phone: user.phone ?? undefined, role: user.role },
      { secret: accessSecret, expiresIn: 900 },
    );

    const refreshToken = this.jwt.sign(
      { sub: user.id },
      { secret: refreshSecret, expiresIn: 604800 },
    );

    return {
      accessToken,
      refreshToken,
      user: { id: user.id, phone: user.phone, role: user.role },
    };
  }

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