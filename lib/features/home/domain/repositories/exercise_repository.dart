import '../../data/models/exercise.dart';

abstract class ExerciseRepository {
  List<Exercise> getAllAvailableExercises();

  List<Exercise> generateCustomExerciseData();
}
