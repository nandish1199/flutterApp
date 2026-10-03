//________HELLO WORLD________//
void main() {
  print("Hello world");
}

//--- Result: Hello world

//_______FUNCTIONS_______//
void main() {
  print("This is the main ");
  calculate(); // every function must be called inside the main function
}

int calculateArea(int length, int width) {
  int area = length * width;
  return area;
}

void calculate() {
  int roomArea = calculateArea(15, 10);
  print("My room area is $roomArea");
}
//--- Result: This is the main
//--- Result: My room area is 150

//_______CLASSES and CONSTRUCTORS_______//
void main() {
  print("This is the main ");
  exercises();
}

class Exercise {
  String name;
  String targetMuscle;
  String difficulty;

  Exercise(this.name, this.targetMuscle, this.difficulty);

  void printDetails() {
    print("exercise name is $name");
    print("target muscle is $targetMuscle");
    print("difficulty level is $difficulty");
  }
}

void exercises() {
  Exercise hammerCurl = Exercise("hammercurl", "biceps", "easy");
  hammerCurl.printDetails();
}

//--- Result: This is the main
//--- Result: exercise name is hammercurl
//--- Result: target muscle is biceps
//--- Result: difficulty level is easy

//_______CONSTRUCTORS ANOTHER EXAMPLE (STUDENTS CLASS)_______//
void main() {
  print("This is the main ");
  fullName();
}

class Students {
  String firstName;
  String lastName;

  Students(this.firstName, this.lastName);

  void printDetails() {
    print("first name is $firstName and last name is $lastName");
  }
}

void fullName() {
  Students nandish = Students("nandish", "hiremath");
  nandish.printDetails();
}

//--- Result: This is the main
//--- Result: first name is nandish and last name is hiremath

//_______LISTS_______//

void main() {
  List<String> meals = ['Upma', 'Chicken Salad', 'Protein Shake'];
  print(meals); // Prints: [Upma, Chicken Salad, Protein Shake]
  print(meals[0]); // Prints: Upma

  // Modifying an item
  meals[1] = 'Lemon Water';
  print(meals); // Prints: [Upma, Lemon Water, Protein Shake]
}

//--- Result: [Upma, Chicken Salad, Protein Shake]
//--- Result: Upma
//--- Result: [Upma, Lemon Water, Protein Shake]

//_______LISTS CORE FUNCTIONS_______//
void main() {
  List<String> workout = ['Squat'];

  // Add a single item to the end of the list
  workout.add('Deadlift');

  // Add multiple items at once
  workout.addAll(['Leg Press', 'Calf Raise']);

  // Insert an item at a specific index position
  workout.insert(1, 'Lunges'); // Puts 'Lunges' right after 'Squat'

  // Remove a specific item
  workout.remove('Leg Press');

  // Remove an item by its index position
  workout.removeAt(0); // Removes 'Squat'

  // Get the total number of items in the list
  int totalExercises = workout.length;
  print("Total exercises: $totalExercises");
}
