import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import { randomUUID } from 'crypto';
import { ConfigService } from '@nestjs/config';

type AccessPayload = {
  sub: string;
  phone?: string;
  role: string;
};

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async requestOtp(phone: string) {
    // DEV mock
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

    const accessSecret =
      this.config.get<string>('JWT_ACCESS_SECRET') ?? 'dev-access-secret';
    const refreshSecret =
      this.config.get<string>('JWT_REFRESH_SECRET') ?? 'dev-refresh-secret';

    const raw = this.config.get<string>('JWT_EXPIRES_IN') ?? '2592000';
    const accessExpiresInSec: number = Number(raw);

    const expires =
      Number.isFinite(accessExpiresInSec) && accessExpiresInSec > 0
        ? accessExpiresInSec
        : 2592000;

    const payload: AccessPayload = {
      sub: user.id,
      phone: user.phone ?? undefined,
      role: user.role,
    };

    const accessToken = this.jwt.sign<AccessPayload>(payload, {
      secret: accessSecret,
      expiresIn: expires,
    });

    const refreshToken = this.jwt.sign<{ sub: string }>(
      { sub: user.id },
      {
        secret: refreshSecret,
        expiresIn: 604800, // 7 days
      },
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