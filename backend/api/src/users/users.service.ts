// src/users/users.service.ts
import { ConflictException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '@prisma/client';
import { UpdateMeDto } from './dto/update-me.dto';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async updateMe(userId: string, dto: UpdateMeDto) {
    try {
      return await this.prisma.user.update({
        where: { id: userId },
        data: {
          displayName: dto.displayName ?? undefined,
          email: dto.email ?? undefined,
        },
        select: {
          id: true,
          phone: true,
          email: true,
          displayName: true,
          role: true,
          status: true,
        },
      });
    } catch (e: any) {
      // ✅ Prisma unique constraint
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        // target จะบอก field ที่ชน เช่น ['email']
        throw new ConflictException('Email นี้ถูกใช้งานแล้ว');
      }
      throw e;
    }
  }
}