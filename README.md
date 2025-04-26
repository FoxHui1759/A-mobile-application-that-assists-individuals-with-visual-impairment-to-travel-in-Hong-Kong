# A-mobile-application-that-assists-individuals-with-visual-impairment-to-travel-in-Hong-Kong

Read another README.md in eyes_on_the_road/ for more instruction for the Flutter App.

## Overview
**Eyes On The Road** is to work as an alternative as a guide dog for working travel guidance in Hong Kong

## Installation

### Flutter App Installation
1. install flutter SDK by the following guide
   - [Windows](https://docs.flutter.dev/get-started/install/windows/mobile)
   - [Mac](https://docs.flutter.dev/get-started/install/macos/mobile-android)
   - [Linux](https://docs.flutter.dev/get-started/install/linux/android) 
2. install the flutter dependencies `flutter pub get`
3. Start a new Android Device (API Level 35) which should have done in the flutter SDK install guide
4. run the app by `flutter run` or click in the android studio

## Coding Standards
Follow the [Flutter Style Guide](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md)

### Code Style Guidelines
- **Indentation**: use 2 spaces
- **Line Length** : Aim a maximum line length of 80-120 characters
- **Naming Conventions**:
	- `lowerCamelCase` for variables and function names
	- `UpperCamelCase` for class names
	- `snake_case` for file names

## Contributing
1. Create a branch for a new feature: `git checkout -b feature/your-feature-name`
2. Commit your changes with meaningful message  
    - Follow the [Git Commit Message Convention](https://www.conventionalcommits.org/en/v1.0.0/)
	- One-line: `git commit -m "<type>[optional scope]: <description>"`
    - Detailed: `git commit`
    - ```git
        <type>[optional scope]: <description>
    
        [optional body]
    
        [optional footer(s)]    
        ```
3. Push to the repo: `git push origin feature/your-feature-name`
4. Do not push UNTESTED CODE to the main branch
