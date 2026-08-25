import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Put,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { ExerciseNotesService } from './exercise-notes.service';
import { UpsertExerciseNoteDto } from './dto/upsert-exercise-note.dto';

@ApiTags('exercise-notes')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('exercises/:exerciseId/note')
export class ExerciseNotesController {
  constructor(private readonly service: ExerciseNotesService) {}

  @Get()
  findOne(
    @CurrentUser() user: { id: string },
    @Param('exerciseId') exerciseId: string,
  ) {
    return this.service.findOne(user.id, exerciseId);
  }

  @Put()
  upsert(
    @CurrentUser() user: { id: string },
    @Param('exerciseId') exerciseId: string,
    @Body() dto: UpsertExerciseNoteDto,
  ) {
    return this.service.upsert(user.id, exerciseId, dto.note);
  }

  @Delete()
  remove(
    @CurrentUser() user: { id: string },
    @Param('exerciseId') exerciseId: string,
  ) {
    return this.service.remove(user.id, exerciseId);
  }
}