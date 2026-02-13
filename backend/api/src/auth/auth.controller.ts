import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { JwtAuthGuard } from './jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('request-otp')
  requestOtp(@Body() body: { phone: string }) {
    return this.authService.requestOtp(body.phone);
  }

  @Post('verify-otp')
  verifyOtp(@Body() body: { phone: string; otp: string; requestId: string }) {
    return this.authService.verifyOtp(body.phone, body.otp, body.requestId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@Req() req: any) {
    const userId = req.user.sub;
    return this.authService.getMe(userId);
  }
}