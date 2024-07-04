import '../models/exercise.dart';

class CustomExerciseGenerator {
  List<Exercise> generateCustomExercises() {
    List<Exercise> exerciseList = [];

    // biceps exercise
    var bicepsExercise = Exercise(
        name: "Biceps Exercise",
        landmarkPoints: ["", ""],
        startAngle: 0,
        halfAngle: 90,
        thresholdAngle: 15);
    exerciseList.add(bicepsExercise);
    return exerciseList;
  }
}
