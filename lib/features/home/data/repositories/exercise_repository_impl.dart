
import 'package:flutter_pose/features/home/data/data_sources/custom_exercise_generator.dart';

import '../../domain/repositories/exercise_repository.dart';
import '../models/exercise.dart';

class ExerciseRepositoryImpl extends ExerciseRepository {

  final CustomExerciseGenerator exerciseGenerator;

  ExerciseRepositoryImpl({required this.exerciseGenerator});

  @override
  List<Exercise> generateCustomExerciseData() {
    return exerciseGenerator.generateCustomExercises();
  }

  @override
  List<Exercise> getAllAvailableExercises() {
    return generateCustomExerciseData();
  }
}
