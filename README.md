# FINAL PROJECT

Original code for final project, bugs included.

# GIFS

![typingtutor](https://github.com/barkeshli-CS066-classroom/99-final-project-typing-tutor-JulioAnzaldo/assets/114134346/86936196-c44d-4073-b54f-f27f4e03e952)

![fallingwordsgame](https://github.com/barkeshli-CS066-classroom/99-final-project-typing-tutor-JulioAnzaldo/assets/114134346/a7bf2950-ad62-422d-bba6-12ac53244c14)

## Features:

- Not Implemented:
  - High Scores
    - Function to compare highest and current score and overide accordingly

<br><br>

- Implemented:
  - Main menu
  - Typing Game
    - Ten constantly randomly generated words
    - "Falling" mechanic
    - Death floor mechanic
  - Typing Tutor Game
    - Randomly generated paragraph
    - Word highlighting
    - Wrong word system
  - Game Statistics
    - WPM counter
    - Score
    - Timer
  - High Scores Menu (not fully functional)
    - Highest score
  
<br><br>

- Partly implemented:
  - High Scores
    - Function that allows user to view stats and highest scores
    - Stores and reads data from file

<br><br>

- Bugs
  - Typing Tutor
     - Word checking does not currently properly highlight words in red
     - When using back space program goes to beginning of new line instead of previous x
  - Typing Game
     - Wrong words do not show up
  - High Scores
     - N/A
  - Game Statistics
     - Timer does not count down properly and blows up
     - WPM on both games broken
     - Score system on Typing Tutor not working as intended

<br><br>

# Reflections:

- I was far too ambitious for my level of skill lmao
  
## LIST OF FUNCTIONS:

```assembly
WordInitializer PROC
    ; purpose: The heart of my code, reads all my words from file. Parses them, and stores pointers to them in arrays
    ; args: no args
    ; affect: no flags or registers affected
    ; return: Stores all words in buffer variable, and pointers in wordPointer variables. As well as storing the number of words read into wordCount var.
WordInitializer ENDP
```

```assembly
Menu PROC
    ; purpose: The main menu to my game, can exit, check high scores, or move to typing/tutor games
    ; args: no args
    ; affect: no flags or registers affected
    ; return: No return but moves to different functions depending on selected option
Menu ENDP
```

```assembly
TypingGame PROC
    ; purpose: The falling words typing game
    ; args: Does not take any args
    ; affect: Yes
    ; return: Does not explicitly return anything, but stores user input in bufferWord
TypingGame ENDP
```

```assembly
CreateTenWords PROC
    ; purpose: This function generates ten random words which are pulled from buffer (our text file)
    ; args: Does not take any args
    ; affect: all registers and flags
    ; return: Does not explicitly return anything, but stores the random words in fallingWords
CreateTenWords ENDP
```

```assembly
TypingTutor PROC
    ; purpose: The typing tutor game, generates one of three paragraphs (they're lyrics to a song) and lets the user practice their typing skills
    ; args: Does not take any args
    ; affect: Yes
    ; return: Does not explicitly return anything, but stores correct user data into bufferParagraph
TypingTutor ENDP
```

```assembly
UpdateGame PROC
    ; purpose: Updates the Y positions of the words in typing game, as well as handles the erasing of previous positions
    ; args: Does not take any args
    ; affect: Affects mostly just edx, esi, and wordPosY
    ; return: Does not return anything but handles game updating
UpdateGame ENDP
```

```assembly
highScores PROC
    ; purpose: Reads highest scores for both Typing Game and Typing Tutor from file as well as highest WPM
    ; args: no args
    ; affect: no flags or registers affected
    ; return: Returns highesat score to highScoreBuffer
highScores ENDP
```

```assembly
centerString PROC USES esi eax ecx
    ; purpose: Centers string on the screen
    ; args: Takes string address into esi, takes desired Y-offset into al, and takes LENGTHOF string into ecx
    ; affect: no flags or registers affected
    ; return: No return, displays strings in center of screen 
centerString ENDP
```

```assembly
displayWords PROC
    ; purpose: Iterates through the ten words in Typing Game and prints all letters (structs in fallingWords)
    ; args: Takes address of wordPositionsX, fallingWords, and sets ecx to 10
    ; affect: no flags or registers affected (other than within the function
    ; return: Does not return anything
displayWords ENDP
```
```assembly
displayStats PROC USES ecx edx
    ; purpose: Displays game statistics (WPM, SCORE, AND TIMER) for both the Tutor and Falling Words gamnes
    ; args: Takes score register (ecx), takes position (dl, dh)
    ; affect: no flags or registers affected (other than within the function)
    ; return: Does not return anything
displayStats ENDP
```
```assembly
InitializeRandomWord PROC USES edi
    ; purpose: Generates random words and coordinates for wordStructs in our fallingWords array
    ; args: Takes Address to current wordStruct in fallingWords into edi
    ; affect: no flags or registers affected (other than within the function)
    ; return: copied string into wordStruct and random x variable
InitializeRandomWord ENDP
```
