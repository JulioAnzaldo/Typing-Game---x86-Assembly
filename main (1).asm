.386
.model flat, stdcall
.stack 4096
INCLUDE Irvine32.inc
ExitProcess PROTO, dwExitCode: DWORD

.data
    ; Prompts
    gameStart BYTE "Typing Game (1), Typing Tutor (2), High Scores (3), Exit (0)", 0
    highScoresPrompt BYTE 0Ah, 0Ah, "Press any button to exit high scores.", 0
    typingTutorStats BYTE "WPM:           Score:           Time left: ", 0
    gamePrompt BYTE "    Welcome to the falling words typing game!", 0
    postGamePrompt BYTE "Menu (1), High Scores(2), Exit(0)", 0
    madeBy BYTE "         Made by: Julio Anzaldo", 0
    
    ; Status updates
    screenTest BYTE "GAME OVER!", 0
    highScore BYTE "Highest Score(s): ", 0
    finalScore BYTE "Final score: ", 0
    
    ; File names
    wordsFileName BYTE "words.txt", 0           ; Text file with a bunch of words
    highScoresFileName BYTE "highscores.txt", 0 ; High scores file to read and write from

    ; Buffer and counter stuff for file input
    wordPointers DWORD 128 DUP (?)  ; Array of pointers to the words used in wordHandler
    buffer BYTE 1024 DUP (?)        ; Stores data
    fileHandle DWORD ?              ; File handle for closing and other stuff
    bufferEnd DWORD ?               ; End of the buffer data
    bytesRead DWORD ?               ; Stores amount of bytes read
    wordCount DWORD 0               ; Number of words read
    newLine BYTE 0                  ; New line counter cause I do not have enough registers for everything
    boolean BYTE 0                  ; ON by default

    ; Temp buffers for game loop
    highScoreBuffer BYTE ?          ; Holds highest score that is read from file
    wordCheckpoint BYTE 0           ; Counter for how many words have elapsed for indexing
    bufferParagraph BYTE ?          ; Holds the "correct" words which will be printed in green
    bufferWord BYTE 8 DUP (0)       ; Used for comparison
    currentWordIndex DWORD 0        ; Index to track current position in the word being matched
    msElapsed WORD 0                ; ms elapsed counter (increments of 50ms)
    score DWORD 0                   ; Score for both games (1 score per correct letter)
    WPM BYTE 0                      ; How many total words elapsed for WPM calculation

    ; Error handling
    fileOpenError BYTE "Could not open file!", 0
    fileReadError BYTE "Could not read data!", 0

    ; Position tracking
    wordPositionsX BYTE ?
    posYCounter DWORD 0
    wordPosX BYTE 0
    wordPosY BYTE 0

    ; Word struct for falling words typing game
    wordStruct STRUCT
        words BYTE 8 DUP (0)
        x BYTE 0
        y BYTE 0
    wordStruct ENDS
    
    ; Array to hold 10 wordStruct instances for the falling words
    fallingWords wordStruct 10 DUP (<>)

.code

;---------------------------------------- Main ----------------------------------------;

main PROC
    ; Handles creating all words and storing them in buffers/arrays
    call WordInitializer

    continuePlaying:
    ; After words are initialized, startup menu, and go from there
    call Menu
    jmp continuePlaying

    INVOKE ExitProcess, 0
main ENDP

;---------------------------------------- Menu ----------------------------------------;

Menu PROC
menuInitialize:
    ; Clear screen
    call Clrscr

    ; Display welcome message
    mov esi, OFFSET gamePrompt
    mov al, 0
    mov ecx, LENGTHOF gamePrompt - 1
    call centerString

    ; Made by string
    mov esi, OFFSET madeBy
    mov al, 1
    mov ecx, LENGTHOF madeBy - 1
    call centerString

    ; Prompt user for input
    mov esi, OFFSET gameStart
    mov al, 4
    mov ecx, LENGTHOF gameStart - 1
    call centerString

    ; Loop until valid input is received
    repeatPrompt:

    ; Clear input
    xor eax, eax

    ; Read user input
    call ReadKey

    ; Compare user input with options
    cmp al, '1'
    je startTypingGame
    cmp al, '2'
    je startTypingTutor
    cmp al, '3'
    je showHighScores
    cmp al, '0'
    je exitProgram

    ; Invalid input, prompt again
    jmp repeatPrompt

exitProgram:
    ; Exit the program
    INVOKE ExitProcess, 0

startTypingGame:
    jmp TypingGame

startTypingTutor:
    jmp TypingTutor

showHighScores:
    ; Display high scores, then go back to menu
    jmp highScores

    ret
Menu ENDP

;---------------------------------------- Typing Game ----------------------------------------;

TypingGame PROC

    ; Clear screen
    call Clrscr

    mov dl, 0
    mov dh, 27
    call Gotoxy

    mov ecx, 118    ; Max X + max word length
    drawFloor:

    mov al, '='
    call WriteChar

    loop drawFloor

    mov [newLine], 0    ; Reset word counter

    ; Initialize Y
    mov wordPosY, 0
    mov dl, 0
    mov dh, [wordPosY]
    call Gotoxy

chekpoint:

    ; Generate the first 10 random letters
    call CreateTenWords

    mov edi, OFFSET fallingWords    ; Load struct array
    push edi

    ; Game loop that handles the mechanics(falling, checking words, etc)
gameLoop:

    ; If a word falls off, end game
    mov al, [wordPosY]
    cmp al, 17          ; Lower floor
    jge PostGameScreen

    pop edi
    mov dl, [edi + wordStruct.x]
    mov dh, [edi + wordStruct.y]
    call Gotoxy

    mov eax, green + (black * 16)   ; Set color of correct words to green
    call SetTextColor

    mov edx, OFFSET bufferWord      ; Display correct words
    call WriteString

    ; Set delay for inputs
    mov eax, 50
    call Delay

    ; Clear prev input
    xor eax, eax

    ; Check for input, if no input, loop
    call ReadKey
    jz finalSection
    
    ; Check if were in the middle of matching a word
    cmp [boolean], 1
    je continueMatching

    ; Search for a matching word
    xor edx, edx                    ; Max searches is 10, so it will not loop forever
    xor esi, esi                    ; Initialize index for bufferWord
comparisonLoop:
    cmp edx, 10                     ; Check if max attempts reached
    je finalSection

    mov bl, [edi + wordStruct.words] ; Load first letter of struct string
    cmp al, bl                       ; Compare it to user input
    je matchFound

    inc edx                         ; Increase amount of words checked
    add edi, SIZEOF wordStruct      ; Move to next struct
    jmp comparisonLoop

continueMatching:
    mov esi, [currentWordIndex]
    mov bl, [edi + wordStruct.words + esi]

    cmp al, bl                      ; Compare it to user input
    jne finalSection                ; If no match, exit

matchFound:

    mov [boolean], 1

    mov [bufferWord + esi], bl      ; Move letter into bufferWord
    inc [currentWordIndex]          ; Move to the next character in the word
    inc ecx                         ; Increase score

    ; Check if the entire word is matched
    mov eax, [currentWordIndex]
    cmp [edi + wordStruct.words + eax], 0 ; Check if end of word (null terminator)
    je wordMatched

    jmp finalSection

wordMatched:
    ; Reset eax and esi
    xor eax, eax
    xor esi, esi

    mov [currentWordIndex], 0       ; Essentially a memory esi

    mov dl, [edi + wordStruct.x]
    mov dh, [edi + wordStruct.y]
    call Gotoxy

    mov al, ' '
    mov ecx, 8
eraseLoop:
    call WriteChar
    loop eraseLoop

    ; Call function to initialize a new random word
    call initializeRandomWord   ; Initialize a new word to replace the completed one
    mov [edi + wordStruct.y], 0       ; Set its position to the top of the screen

    ; Clear buffer word
    mov edi, OFFSET bufferWord      ; Restore origional edi
    push edi                        ; Save it
    mov ecx, 8                      ; Number of bytes to clear
    mov al, 0                       ; What we want to set it to
    rep stosb                       ; Clear bufferWord

    mov [boolean], 0            ; Reset boolean, since we are no longer in the middle of a word

    inc [newLine]               ; Increase words read
    jmp finalSection

finalSection:

    ; Save the current EDI for the next iteration
    push edi

    ; Update word positions / Erase prev input / other
    call UpdateGame

    ; Loop again
    jmp gameLoop
    
TypingGame ENDP

;---------------------------------------- Create Ten Words ----------------------------------------;

CreateTenWords PROC

    ; Seed number generator
    call Randomize

    ; Load array of word structs
    mov edi, OFFSET fallingWords

    ; Initialize 10 random words
    mov ecx, 10
initWordsLoop:
    
    ; Set the y position to ecx (top of the screen first)
    mov [edi + wordStruct.y], cl  ; Start at the top (y = ec)

    call InitializeRandomWord
    add edi, SIZEOF wordStruct
    loop initWordsLoop

    ret

CreateTenWords ENDP

;---------------------------------------- Initialize Random Word ----------------------------------------;

InitializeRandomWord PROC USES edi
    ; edi: points to the current wordStruct in the fallingWords

    ; Generate a random index (0 to 127)
    mov eax, wordCount      ; Number of words in the pointer array
    call RandomRange

    ; Load the address of the string from the wordPointers array using the random index
    mov esi, OFFSET wordPointers
    mov esi, [esi + eax * 4]

    ; Initialize the x and y positions randomly
    mov eax, 110        ; Assuming 80 columns on the screen
    call RandomRange
  
    ; Store the random x position in the wordStruct
    mov [edi + wordStruct.x], al ; Random x position

    ; Copy the string to the words field in the wordStruct
    lea edi, [edi + wordStruct.words]
copyLoop:
    mov al, [esi]      ; Load byte from the source string
    mov [edi], al      ; Store byte into the destination buffer

    inc esi            ; Move to the next byte in the source string
    inc edi            ; Move to the next byte in the destination buffer

    cmp al, 0        ; Check if it was the null terminator
    jne copyLoop     ; If not, continue copying

    ret
InitializeRandomWord ENDP

;---------------------------------------- Typing Tutor ----------------------------------------;

TypingTutor PROC

    mov edi, OFFSET wordPointers ; Load buffer with all the word pointers

    mov [score], 0     ; Reset score
    mov [WPM], 0       ; Reset WPM
    mov [msElapsed], 0 ; Reset ms elapsed var

generateParagraph:

    ; Clear screen
    call Clrscr

    mov dl, 10  ; x = 10
    mov dh, 10  ; y = 10
    push edx
    call Gotoxy ; Set starting position
    
    call Randomize ; Seed generator
    mov eax, 2
    call RandomRange ; [0, 1)
    cmp eax, 0
    jne secondParagraph

    ; If 0, generate first paragraph
    xor esi, esi               ; Counter for newlines
    mov ebx, 0                 ; The amount of words that will be used in index loop (for moving esi)
    mov [wordCheckpoint], 27
    mov ecx, 28                ; The first 28 words of buffer (and the song)
firstSection:
    mov edx, [edi]      ; Load address to nth word
    call WriteString    ; Write it
    mov al, ' '
    call WriteChar
    add edi, TYPE DWORD ; Move to next words pointer 
    inc esi             ; Increment counter
    cmp esi, 7          ; Check if 7 words have been printed
    jl skip             ; If not skip

    pop edx             ; If so, restore position
    inc dh              ; Increment Y
    call Gotoxy         ; Move to new Y
    push edx            ; Save edx again
    xor esi, esi        ; Reset counter

    skip:
    loop firstSection

    jmp doneGenerating

    ; Else, generate second paragraph
secondParagraph:

    ; If 0, generate first paragraph
    xor esi, esi                ; Counter for newlines
    add edi, TYPE DWORD * 28    ; Move edi to the second word pointer (start of the second paragraph)
    mov ebx, 28                 ; The amount of words that will be used in index loop
    mov [wordCheckpoint], 33
    mov ecx, 34                 ; The second part and 38 words of buffer (and the song)
secondSection:
    mov edx, [edi]
    call WriteString    ; Write it
    mov al, ' '
    call WriteChar
    add edi, TYPE DWORD ; Move to next words pointer 
    inc esi             ; Increment counter
    cmp esi, 7          ; Check if 7 words have been printed
    jl skipSection      ; If not skip

    pop edx             ; If so, restore position
    inc dh              ; Increment Y
    call Gotoxy         ; Move to new Y
    push edx            ; Save edx again
    xor esi, esi        ; Reset counter

    skipSection:
    loop secondSection

    jmp doneGenerating

doneGenerating:

    mov dl, 10         ; x = 10
    mov dh, 10         ; y = 10
    call Gotoxy        ; Go back to starting position, to make paragraphs overlap

    mov edx, OFFSET buffer ; Load buffer address

    ; Compute the distance in bytes between the buffer and the second paragraph
    xor eax, eax        ; Words elapsed
    xor esi, esi        ; Initialize index
    
moveIndexToNewParagraph:
    cmp eax, ebx        ; Check if we have reached our destination
    je adjustmentDone
    cmp buffer[esi], 0  ; If not there yet, check if byte is a null terminator
    jne noBueno
    
    add esi, 2          ; If so, increase esi (index) by two
    inc eax             ; Increase words found

    jmp moveIndexToNewParagraph ; Loop again

    noBueno:            ; If not a null terminator, just loop again
    inc esi             ; Move to next word

    jmp moveIndexToNewParagraph

adjustmentDone:

    xor ecx, ecx                     ; Reset score tracker
    mov [wordPosx], 10               
    mov [wordPosY], 10

BigLoop:

    mov bl, [wordCheckpoint]
    cmp [newLine], bl
    jge generateParagraph

    cmp [newLine], 7    ; Checks if 7 words have passed (two null terminators)
    jne miniSkip        ; If not, skip

    mov dl, 10          ; mov x to beginning (10)
    inc dh              ; Increase Y
    call Gotoxy         ; Move to new position

    mov [newLine], 0    ; Reset counter
    inc [wordPosY]      ; Save New Y
    mov [wordPosX], 10  ; Reset X

    jmp continueLoop

miniSkip:

    cmp BYTE PTR [buffer + esi], 0  ; Check if letter at index is a null terminator
    jne inputLoop
    mov al, ' '                     ; If so, write a space on screen
    call WriteChar

    add esi, 2            ; Move to the next letter
    inc [WPM]             ; Increase the words per minute counter
    inc [newLine]         ; New line counter, amount of words elapsed
    inc [wordPosX]        ; Save New X

    jmp BigLoop           ; Continue with the next iteration

inputLoop:

    mov eax, 50
    call Delay           ; Set delay of 50ms

    add [msElapsed], 1  ; Add 50ms to ms elapsed

    call ReadKey         ; Grab user input
    jz continueLoop

    cmp al, 08           ; Check if backspace was pressed
    je errorDeleted      ; If so, handle

    ; Check if the input character is an apostrophe
    cmp al, 39           ; ASCII code for apostrophe '
    je apostrophe        ; If it's an apostrophe, jump to handle it

    cmp al, 32
    je continueLoop

    cmp al, buffer[esi]  ; Check if typed letter is correct
    jne handleIncorrect  ; If not, skip next part

    mov [bufferWord], al ; If so, save letter into bufferWord
    inc esi              ; Increment index/counter
    mov [boolean], 0     ; Reset boolean variable

    mov eax, green + (black * 16)   ; Set color of correct words to green
    call SetTextColor

    
    push edx
    mov edx, OFFSET bufferWord      ; Display those words
    call WriteString
    pop edx

    inc [wordPosX]                  ; Save X
    inc ecx                        ; Increase score

    jmp continueLoop

apostrophe:
    ; Since "'" is a valid character in the text, handle it similarly to correct letters
    mov [bufferWord], al ; Save the apostrophe into bufferWord
    inc esi              ; Increment index/counter
    mov [boolean], 0     ; Reset boolean variable

    mov eax, green + (black * 16)   ; Set color of correct words to green
    call SetTextColor
    push edx
    mov edx, OFFSET bufferWord      ; Display those words
    call WriteString
    pop edx

    inc [wordPosX]                  ; Save X
    inc ecx                         ; Increase score

    jmp continueLoop

handleIncorrect:
    ; Set the color to red for displaying incorrect letters
    mov eax, red + (black * 16)   ; Set color of incorrect words to red
    call SetTextColor

    mov al, buffer[esi]           ; Load the correct letter into AL from buffer
    call WriteChar                ; Display the incorrect letter

    ; Move the cursor back to the position of the incorrect letter
    dec dl                        ; Move X position back by one
    dec [wordPosX]                ; Save X
    call Gotoxy                   ; Move the cursor to the previous position

    jmp continueLoop

errorDeleted:

    ; Set the color back to white and restore the correct letter
    mov eax, white + (black * 16) ; Set color back to white
    call SetTextColor
    mov al, buffer[esi]           ; Load the correct letter into AL from buffer
    call WriteChar

    ; Move the cursor back to the position of the incorrect letter
    dec dl                        ; Move X position back by one
    dec [wordPosX]                ; Save X
    call Gotoxy                   ; Move the cursor to the previous position

    jmp continueLoop

continueLoop:
    
    mov dl, 10         ; x = 10
    mov dh, 5          ; y = 5
    call displayStats  ; Write stats at this location

    mov dl, [wordPosX]
    mov dh, [wordPosY]
    call Gotoxy

    jmp BigLoop

    ret

TypingTutor ENDP

;---------------------------------------- UpdateGame ----------------------------------------;

UpdateGame PROC

    PUSHAD

    ; Check counter, check if one second has elapsed (since our delay is 100ms and 1000(1 sec) / 100 = 10)
    mov eax, [posYCounter]
    mov ebx, 20             ; 50 ms * 20 = 1000 ms (1 second)
    cmp eax, ebx
    jne skipIncrementAndErase

    ; Reset "counter" to zero
    mov [posYCounter], 0

    inc [wordPosY]

    add [msElapsed], 20     ; Only updates once every 20 iterations * 50ms = 1 second

    mov dl, 10         ; x = 10
    mov dh, 28         ; y = 30
    call displayStats  ; Write stats at this location

     ; Load array of word structs
    mov edi, OFFSET fallingWords

    ; Initialize 10 random words
    mov ecx, 10
eraseLoop:
    
    ; Set the y position to ecx (top of the screen first)
    mov dl, [edi + wordStruct.x]  ; Move to that struct x pos
    mov dh, [edi + wordStruct.y]  ; Move to the y pos
    call Gotoxy

    push ecx
    mov ecx, 8
    writeSpaces:

    mov al, ' '
    call WriteChar
    loop writeSpaces
    pop ecx

    add edi, SIZEOF wordStruct
    loop eraseLoop

    ; Load array of word structs again
    mov edi, OFFSET fallingWords

    ; Update y position of all words
    mov ecx, 10
updateYPos:
    
    ; Increment all the Y
    inc [edi + wordStruct.y]
    add edi, SIZEOF wordStruct ; Move to next Y
    loop updateYPos

    ; Reset word color to white
    mov eax, white + (black * 16)
    call SetTextColor

    ; Display our words (used for testing buffers and pointer arrays)
    call displayWords

skipIncrementAndErase:
    inc [posYCounter]

    POPAD

    ret
UpdateGame ENDP


;---------------------------------------- Post Game Screen ----------------------------------------;

PostGameScreen PROC
    ; Clear screen
    call Clrscr

    ; Set text color to white
    mov eax, white + (black * 16)
    call SetTextColor

    ; Load argumets: String address, length - null terminator, and Y offset
    mov esi, OFFSET screenTest
    mov al, 1
    mov ecx, LENGTHOF screenTest - 1
    call centerString

    ; Show user their final score
    mov esi, OFFSET finalScore
    mov al, 2
    mov ecx, LENGTHOF finalScore - 1
    call centerString

    mov eax, DWORD PTR [score]
    call WriteInt

    ; Display our string
    mov esi, OFFSET PostGamePrompt
    mov al, 5
    mov ecx, LENGTHOF PostGamePrompt - 1
    call centerString

    ; Read user input
    call ReadChar

    ; Compare user input with options
    cmp al, '1'
    je returnToMenu
    cmp al, '2'
    je showHighScores
    cmp al, '0'
    je exitProgram

    ; Invalid input, loop again
    jmp PostGameScreen

returnToMenu:
    jmp Menu

showHighScores:

    ; Display high scores
    jmp highScores
    jmp postGameScreen

exitProgram:
    ; Exit the program
    INVOKE ExitProcess, 0

    ret

PostGameScreen ENDP

;---------------------------------------- centerString ----------------------------------------;

centerString PROC USES esi eax ecx

    ; Save eax (Y offset)
    push eax

    ; Load max x - 1 and y - 1
    ;call GetMaxXY
    mov dl, 90
    mov dh, 23

    ; Calculate the x for centering the string
    mov ebx, ecx      ; Copy the length of the string to ebx
    shr ebx, 1        ; Divide the length by 2
    sub dl, bl        ; Subtract half the length from max x
    shr dl, 1         ; Divide the result by 2 to get the starting x
    test ecx, 1       ; Check if the length is odd
    jnz oddLength     ; If odd length, skip adjusting x

    ; If the length is even, adjust x by 1
    inc dl

oddLength:
    ; Restore eax (Y offset)
    pop eax

    ; Calculate the y for centering the string
    shr dh, 1         ; Divide max y by 2 for vertical centering
    add dh, al        ; Add the specified Y offset from the middle
    call Gotoxy       ; Move to the calculated x and y coordinates

    ; Load passed string address and write to screen
    mov edx, esi      ; Load the address of the string
    call WriteString  ; Write the string to the screen

    ret

centerString ENDP


;---------------------------------------- High Scores ----------------------------------------;

highScores PROC

    ; Clear screen
    call Clrscr

    ; Clear eax
    xor eax, eax

    ; Load text file
    mov edx, OFFSET highScoresFileName
    call OpenInputFile

    ; Store returned file handle
    mov fileHandle, eax

    ; Check if file was succsesfully opened
    cmp eax, 0
    je fileNotFound

    ; Set up ReadFromFile
    mov eax, fileHandle     ; File handle
    mov edx, OFFSET buffer  ; Buffer address
    mov ecx, SIZEOF buffer  ; Size of the buffer

    ; Read the data from our file and store number of bytes read
    call ReadFromFile
    mov bytesRead, eax

    ; Check if reading was succsesful
    cmp eax, 0
    je inputNotRead

    ; "Final score: "
    mov edx, OFFSET highScore
    call WriteString

    ; Null-terminate the buffer variable
    mov edx, OFFSET buffer  ; Load buffer address
    add edx, eax            ; Point to the byte after the last read byte
    mov BYTE PTR [edx], 0   ; Null-terminate the string

    ; Show high score(s) #
    mov edx, OFFSET buffer
    call WriteString

    ; Display high scores string
    mov edx, OFFSET highScoresPrompt
    call WriteString

pressAnyButton:

    ; Clear input
    xor eax, eax
    
    call ReadChar

    ; Jump to end of high scores method
    jmp Done

    fileNotFound:

    ; "Could not open file"
    mov edx, OFFSET fileOpenError
    call WriteString
    jmp Done

    inputNotRead:

    ; "Could not read file"
    mov edx, OFFSET fileReadError
    call WriteString

    Done:

    ; Close file and exit method
    mov eax, fileHandle
    call CloseFile

    ret

highScores ENDP

;---------------------------------------- Word Initializer ----------------------------------------;

WordInitializer PROC

    ; Load word file
    mov edx, OFFSET wordsFileName
    call OpenInputFile

    ; Store file handle
    mov fileHandle, eax

    ; Check if the file was successfully opened
    cmp eax, 0
    je ErrorOpening

    ; Load words into buffer
    mov eax, fileHandle        ; File handle
    mov edx, OFFSET buffer     ; Address of the buffer
    mov ecx, SIZEOF buffer - 1 ; Size of the buffer minus the null terminator
    call ReadFromFile

    ; Store the number of bytes read and null terminate buffer
    mov bufferEnd, eax
    mov BYTE PTR [buffer + eax], 0

    ; Parse the buffer and store pointers to words
    mov esi, OFFSET buffer          ; ESI points to the start of the buffer
    mov edi, OFFSET wordPointers    ; EDI points to the word pointers array
    xor ecx, ecx                    ; Clear ecx
    mov ebx, bufferEnd              ; Use EBX as a counter for processed bytes

    ; Boolean to check if word is first
    mov edx, 1 ; Default is true to grab very first word, will be set off after first use

ParseBuffer:
    cmp ebx, 0               ; Check if end of buffer
    jle Done
    cmp BYTE PTR [esi], 0
    je Done
    cmp BYTE PTR [esi], ' '  ; Check for space
    je SkipSpace
    cmp BYTE PTR [esi], 0Dh  ; Check for carriage return
    je SkipSpace
    cmp BYTE PTR [esi], 0Ah  ; Check for newline
    je SkipSpace

    cmp edx, 1  ; Check if letter is first in word, if not, skip storing address
    jnz NextChar

    ; Store the pointer to the start of the word
    mov [edi], esi
    add edi, TYPE DWORD ; Move pointer array address up 4 bytes to next location, DWORD/Address size
    inc ecx             ; Increase amount of words read
    mov wordCount, ecx  ; Save amount of words into our var
    mov edx, 0          ; If we save address, all letters after this one are no longer first

NextChar:
    ; Move to the next word
    add esi, TYPE BYTE
    dec ebx             ; Decrease the amount of bytes left to read
    jmp ParseBuffer

SkipSpace:
    ; Replace newline with null terminator, to seperate words
    mov BYTE PTR [esi], 0
    mov edx, 1              ; Set first word boolean back to true
    jmp NextChar

ErrorOpening:
    ; Handle file open error
    mov edx, OFFSET fileOpenError
    call WriteString
    jmp Done

Done:
    ; Close the file if it was successfully opened
    mov eax, fileHandle
    call CloseFile

    ret

WordInitializer ENDP

;---------------------------------------- Display Words ----------------------------------------;

displayWords PROC

    ; Display all words in their respective positions on the screen

    ; Initialize variables
    mov ecx, 10                   ; Number of words to display
    mov edi, OFFSET fallingWords  ; Pointer to the beginning of word array

displayLoop:
    ; Get word coordinates
    mov dl, [edi + wordStruct.x]  ; Get x coordinate
    mov dh, [edi + wordStruct.y]  ; Get y coordinate

    ; Set cursor position
    call Gotoxy

    ; Display word
    lea esi, [edi + wordStruct.words]  ; Pointer to the word string
printLoop:
    mov al, [esi]      ; Load first character of the word
    cmp al, 0          ; Check for null terminator
    je endPrint        ; If null terminator, end printing

    call WriteChar

    inc esi            ; Move to next character
    jmp printLoop      ; Repeat until null terminator

endPrint:
    ; Move to next word in the array
    add edi, SIZEOF wordStruct

    ; Decrement word counter
    loop displayLoop
    ret

displayWords ENDP

;---------------------------------------- Display Stats ----------------------------------------;

displayStats PROC USES ecx edx
    ; ECX:  Takes current score

    PUSHAD             ; Save all general-purpose registers

    call Gotoxy        ; Set position for stats string
    mov ebx, edx       ; Save string position
    push ecx           ; Save score

    ; Set the color back to white
    mov eax, white + (black * 16)    ; Set color back to white
    call SetTextColor

    mov edx, OFFSET typingTutorStats ; Load stats string
    call WriteString

    ; Display the one-minute countdown timer
    mov eax, DWORD PTR [msElapsed]   ; Load amount of ms passed into ECX
    mov ecx, 20                      ; 1 second = 20 * 50 ms
    xor edx, edx
    div ecx                          ; EAX = EAX / 20, EAX now contains seconds elapsed
    mov esi, 60                      ; Start with 60 seconds
    sub esi, eax                     ; Subtract elapsed seconds from 60
    mov eax, esi                     ; Move remaining seconds to EAX

    ; Check if the remaining seconds are negative
    test eax, eax                   ; Test if EAX is negative
    js negativeRemainder            ; Jump to negativeRemainder if negative

    ; If remaining seconds are positive or zero, write the remaining seconds
    call WriteInt                    ; Write the remaining seconds
    jmp endCountdown                 ; Jump to endCountdown

negativeRemainder:
    call PostGameScreen

endCountdown:

    mov edx, ebx                     ; Restore position
    add dl, 5                        ; Set position for WPM variable
    call Gotoxy

    ; Check if newLine is zero to avoid division by zero
    mov eax, DWORD PTR [newLine]   ; Load amount of ms passed
    cmp eax, 0
    je skipWPM                       ; If words elapsed is zero, skip WPM calculation

    ; Check if msElapsed is zero to avoid division by zero
    mov eax, DWORD PTR [msElapsed]   ; Load amount of ms passed
    cmp eax, 0
    je skipWPM                       ; If msElapsed is zero, skip WPM calculation

    ; Calculate the number of seconds elapsed
    xor edx, edx                     ; Clear EDX before division
    mov eax, DWORD PTR [msElapsed]   ; Move msElapsed to EAX
    mov ecx, 20                      ; 1 second = 1000 ms
    div ecx                          ; EAX = EAX / 1000, EAX now contains seconds elapsed

    ; Check if the number of seconds elapsed is zero to avoid division by zero
    cmp eax, 0
    je skipWPM                      ; If seconds elapsed is zero, skip WPM calculation

    ; Calculate WPM
    mov ecx, eax                     ; Move seconds elapsed to ECX
    mov eax, DWORD PTR [newLine]     ; Load amount of words passed into EAX
    xor edx, edx                     ; Clear EDX before division
    div ecx                          ; EAX = EAX / seconds, EAX now contains WPM
    call WriteInt                    ; Write the calculated WPM

    jmp skipWPM

skipWPM:
    mov edx, ebx
    add dl, 22                       ; Set position for score variable
    call Gotoxy
    
    pop ecx                          ; Restore score
    mov al, cl                       ; Load score
    call WriteInt                    ; Write it

    POPAD                            ; Restore all general-purpose registers

    ret

displayStats ENDP

END main