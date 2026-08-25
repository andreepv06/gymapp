import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { SessionSetsService } from './session-sets.service';
import { CreateSessionSetDto } from './dto/create-session-set.dto';
import { UpdateSessionSetDto } from './dto/update-session-set.dto';

@ApiTags('session-sets')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller()
export class SessionSetsController {
  constructor(private readonly service: SessionSetsService) {}

  @Get('sessions/:sessionId/sets')
  findAll(
    @CurrentUser() user: { id: string },
    @Param('sessionId') sessionId: string,
  ) {
    return this.service.findAllForSession(user.id, sessionId);
  }

  @Post('sessions/:sessionId/sets')
  create(
    @CurrentUser() user: { id: string },
    @Param('sessionId') sessionId: string,
    @Body() dto: CreateSessionSetDto,
  ) {
    return this.service.create(user.id, sessionId, dto);
  }

  @Patch('session-sets/:id')
  update(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: UpdateSessionSetDto,
  ) {
    return this.service.update(user.id, id, dto);
  }

  @Delete('session-sets/:id')
  remove(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.service.remove(user.id, id);
  }
}