import { Body, Controller, Patch, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UsersService } from './users.service';
import { UpdateMeDto } from './dto/update-me.dto';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @UseGuards(JwtAuthGuard)
  @Patch('me')
  async updateMe(@Req() req: any, @Body() body: UpdateMeDto) {
    return this.usersService.updateMe(req.user.sub, body);
  }
}