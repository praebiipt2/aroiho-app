import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { PaymentsService } from './payments.service';

@UseGuards(AuthGuard('jwt'))
@Controller('v1/payments')
export class PaymentsController {
  constructor(private readonly service: PaymentsService) {}

  @Post('create-intent')
  async createIntent(@Req() req: any, @Body() body: any) {
    return this.service.createIntent(
      req.user.id ?? req.user.sub,
      body.orderId,
      body.provider ?? 'PROMPTPAY',
    );
  }

  @Post('webhook')
  async webhook(@Body() body: any) {
    return this.service.webhook(body.paymentId, body.event);
  }
}