import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { TrainingModesService } from './training-modes.service';
import { CreateTrainingModeDto } from './dto/create-training-mode.dto';

@ApiTags('training-modes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('training-modes')
export class TrainingModesController {
  constructor(private readonly service: TrainingModesService) {}

  @Get()
  findAll(
    @CurrentUser() user: { id: string },
    @Query('all') all?: string,
  ) {
    return all === 'true'
      ? this.service.findAllForUser(user.id)
      : this.service.findAvailableForUser(user.id);
  }

  @Get(':id')
  findOne(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.service.findOne(user.id, id);
  }

  @Post()
  create(
    @CurrentUser() user: { id: string },
    @Body() dto: CreateTrainingModeDto,
  ) {
    return this.service.create(user.id, dto);
  }

  // Nuova versione (mai una modifica in place — vedi commento nel service)
  @Put(':id')
  createNewVersion(
    @CurrentUser() user: { id: string },
    @Param('id') id: string,
    @Body() dto: CreateTrainingModeDto,
  ) {
    return this.service.createNewVersion(user.id, id, dto);
  }

  @Post(':id/set-default')
  setDefault(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.service.setDefault(user.id, id);
  }

  @Delete(':id')
  remove(@CurrentUser() user: { id: string }, @Param('id') id: string) {
    return this.service.softDelete(user.id, id);
  }
}