import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles =
      this.reflector.getAllAndOverride<string[]>('roles', [
        context.getHandler(),
        context.getClass(),
      ]) ?? [];

    // ไม่มี @Roles() -> ผ่าน
    if (requiredRoles.length === 0) return true;

    const req = context.switchToHttp().getRequest();
    const role: string | undefined = req.user?.role;

    if (!role) throw new ForbiddenException('Missing role');
    if (!requiredRoles.includes(role)) throw new ForbiddenException('Forbidden');

    return true;
  }
}