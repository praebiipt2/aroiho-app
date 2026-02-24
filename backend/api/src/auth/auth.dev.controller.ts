import { Body, Controller, Post } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@Controller('v1/auth/dev')
export class AuthDevController {
  constructor(private readonly jwt: JwtService) {}

  @Post('mint-token')
  mint(@Body() body: any) {
    const sub = body.sub ?? body.userId ?? 'rider-dev';
    const role = body.role ?? 'RIDER';
    const phone = body.phone ?? '0999999999';

    return {
      token: this.jwt.sign({ sub, phone, role }),
      payload: { sub, phone, role },
    };
  }
}