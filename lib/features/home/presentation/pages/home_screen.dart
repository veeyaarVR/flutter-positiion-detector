import 'package:flutter/material.dart';
import 'package:flutter_pose/features/home/data/data_sources/custom_exercise_generator.dart';
import 'package:flutter_pose/features/home/data/repositories/exercise_repository_impl.dart';
import 'package:flutter_pose/features/home/domain/repositories/exercise_repository.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_route_constants.dart';
import '../../data/models/exercise.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Exercise> customExercises = [];

  @override
  void initState() {
    super.initState();
    final CustomExerciseGenerator exerciseGenerator = CustomExerciseGenerator();
    final ExerciseRepository exerciseRepository =
        ExerciseRepositoryImpl(exerciseGenerator: exerciseGenerator);
    setState(() {
      customExercises = exerciseRepository.getAllAvailableExercises();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Ther@Home"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Exercises',
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                )),
            ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: customExercises.length,
                itemBuilder: (BuildContext context, int index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        GoRouter.of(context)
                            .pushNamed(AppRouteConstants.cameraPage);
                      },
                      style: ButtonStyle(
                        backgroundColor:
                            const MaterialStatePropertyAll(Colors.indigo),
                        shape: MaterialStateProperty.all<OutlinedBorder>(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      child: Text(
                        customExercises[index].name,
                        style: const TextStyle(
                          color: Color(0xFFFFFFFF),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                })
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
