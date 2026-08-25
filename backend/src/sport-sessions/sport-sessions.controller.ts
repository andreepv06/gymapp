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
import { SportSessionsService } from './sport-sessions.service';
import { CreateSportSessionDto } from './dto/create-sport-session.dto';
import { UpdateSportSessionDto } from './dto/update-sport-session.dto';

@ApiTags('sport-sessions')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('sport-sessions')
export class SportSessionsController {
  constructor(private readonly service: SportSessionsService) {}

  @Get()
  findAll(@CurrentUser() user: { id: string }) {
    return this.service.findAllForUser(user.id);
  }

  @Get(':id')
  findOne(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.service.findOne(user.id, id);
  }

  @Post()
  create(
    @CurrentUser() user: { id: string },
    @Body() dto: CreateSportSessionDto,
  ) {
    return this.service.create(user.id, dto);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: UpdateSportSessionDto,
  ) {
    return this.service.update(user.id, id, dto);
  }

  @Delete(':id')
  remove(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.service.remove(user.id, id);
  }
}