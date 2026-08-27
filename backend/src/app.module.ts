import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { HealthModule } from './common/health/health.module';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ExercisesModule } from './exercises/exercises.module';
import { WorkoutsModule } from './workouts/workouts.module';
import { SessionsModule } from './sessions/sessions.module';
import { TrainingModesModule } from './training-modes/training-modes.module';
import { GoalsModule } from './goals/goals.module';
import { SportSessionsModule } from './sport-sessions/sport-sessions.module';
import { AdminModule } from './admin/admin.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
    PrismaModule,
    HealthModule,
    UsersModule,
    AuthModule,
    ExercisesModule,
    WorkoutsModule,
    SessionsModule,
    TrainingModesModule,
    GoalsModule,
    SportSessionsModule,
    AdminModule,
  ],
})
export class AppModule {}