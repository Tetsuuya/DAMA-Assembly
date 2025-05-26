.data
    # Board representation (0 = empty, 1 = black pawn, 2 = white pawn)
    board: .space 64
    
    # Messages
    border1:  .asciiz "+============================================================+\n"
    welcome_msg: .asciiz "+                   D A M A   T A   B A I!                   +\n"
    border2:  .asciiz "+============================================================+\n"
    choose_color: .asciiz "Choose your color: 1 for black (X), 2 for white (O): "
    current_player_msg: .asciiz "Current player: "
    player1: .asciiz "Player 1 (X)\n"
    player2: .asciiz "Player 2 (O)\n"
    enter_move: .asciiz "Enter your move (e.g., a3 b4): "
    invalid_move: .asciiz "Invalid move! Try again.\n"
    game_over: .asciiz "Game Over!\n"
    win_black: .asciiz "Black (X) wins!\n"
    win_white: .asciiz "White (O) wins!\n"
    instructions: .asciiz "Instructions:\n- Choose your color: 1 for black (X), 2 for white (O)\n- Enter moves in the format: a3 a4 (from-to)\n- Only diagonal moves are allowed\n- To capture, jump over an opponent's piece (e.g., a3 c5)\n- The game ends when one player has no pawns left\n"
    
    # Box drawing characters
    horizontal: .asciiz "---"
    vertical: .asciiz "|"
    space: .asciiz "     "
    x_pawn: .asciiz " X "
    o_pawn: .asciiz " O "
    empty: .asciiz "   "
    unusable: .asciiz " / "
    
    # Column letters
    column_letters: .asciiz "A B C D E F G H"
    
    # Current player (1 = black, 2 = white)
    current_player_num: .word 1
    player_color: .word 1

    row_sep:    .asciiz " --- --- --- --- --- --- --- --- \n"
    cell_row:   .asciiz "|   |   |   |   |   |   |   |   |"
    newline:    .asciiz "\n"
    col_labels: .asciiz "  A   B   C   D   E   F   G   H"

    move_str: .space 32   # Allow for longer input
    move_coords: .space 16  # Store up to 8 (col,row) pairs

    invalid_turn_p1: .asciiz "Invalid! Player 1 is on move.\n"
    invalid_turn_p2: .asciiz "Invalid! Player 2 is on move.\n"

.text
main:
    # Print top border
    li $v0, 4
    la $a0, border1
    syscall
    # Print welcome message
    li $v0, 4
    la $a0, welcome_msg
    syscall
    # Print bottom border
    li $v0, 4
    la $a0, border2
    syscall
    # Print instructions
    li $v0, 4
    la $a0, instructions
    syscall

    # Print a blank line for spacing
    la $a0, newline
    li $v0, 4
    syscall

    # Ask for player color
    li $v0, 4
    la $a0, choose_color
    syscall
    li $v0, 5
    syscall
    sw $v0, player_color

    # Initialize board (always use (row+col)%2==1 for pawns)
    la $t0, board      # $t0 = base address of board
    li $t2, 0          # $t2 = index (0..63)
    li $t7, 8          # $t7 = 8 (for division)
init_board_loop:
    div $t2, $t7
    mfhi $t3           # $t3 = col = $t2 % 8
    mflo $t4           # $t4 = row = $t2 / 8
    add $t5, $t3, $t4  # $t5 = row + col
    andi $t5, $t5, 1   # $t5 = (row + col) % 2
    bne $t5, 1, init_board_unplayable
    # Playable square (always black squares)
    blt $t4, 3, init_board_black
    bgt $t4, 4, init_board_white
    # Middle rows are empty
    sb $zero, 0($t0)
    j init_board_next
init_board_black:
    li $t6, 1
    sb $t6, 0($t0)
    j init_board_next
init_board_white:
    li $t6, 2
    sb $t6, 0($t0)
    j init_board_next
init_board_unplayable:
    sb $zero, 0($t0)
init_board_next:
    addi $t0, $t0, 1
    addi $t2, $t2, 1
    blt $t2, 64, init_board_loop

    # Set current player to black (1)
    li $t0, 1
    sw $t0, current_player_num

    # Game loop
main_game_loop:
    jal print_board
    # Print current player
    li $v0, 4
    la $a0, current_player_msg
    syscall
    lw $t0, current_player_num
    beq $t0, 1, print_p1
    li $v0, 4
    la $a0, player2
    syscall
    j get_move
print_p1:
    li $v0, 4
    la $a0, player1
    syscall
    
get_move:
    # Prompt for move
    li $v0, 4
    la $a0, enter_move
    syscall
    # Read move as string
    la $a0, move_str
    li $a1, 32
    li $v0, 8
    syscall
    
    # Parse input into move_coords
    jal parse_move_str
    move $s0, $v0      # $s0 = count of moves
    bne $s0, 2, invalid_move_msg  # Must be exactly 2 coordinates for a move
    
    # Use move_coords for src and dst
    la $t8, move_coords
    lb $t1, 0($t8)      # src_col
    lb $t2, 1($t8)      # src_row
    lb $t3, 2($t8)      # dst_col
    lb $t4, 3($t8)      # dst_row
    
    # Calculate source index
    mul $t0, $t2, 8
    add $t0, $t0, $t1
    lb $t5, board($t0)
    
    # Check if source piece belongs to current player
    lw $t6, current_player_num
    bne $t5, $t6, invalid_turn
    
    # Validate and make move
    move $a0, $t1  # src_col
    move $a1, $t2  # src_row
    move $a2, $t3  # dst_col
    move $a3, $t4  # dst_row
    jal validate_and_move
    beq $v0, 0, invalid_move_msg
    
    # After valid move, print board
    jal print_board
    
    # Check if this was a capture move
    sub $t5, $a3, $a1
    abs $t5, $t5
    bne $t5, 2, move_done  # If not a capture move, switch player
    
    # Check for additional capture opportunities from the new position
    move $a0, $a2  # dst_col becomes new src_col
    move $a1, $a3  # dst_row becomes new src_row
    jal check_additional_capture
    beq $v0, 0, move_done  # If no more captures possible, switch player
    
    # If additional capture is possible, continue turn
    j main_game_loop
    
move_done:
    # Check win
    jal check_win
    bnez $v0, end_game
    # Switch player
    lw $t0, current_player_num
    beq $t0, 1, switch_to_white
    li $t0, 1
    sw $t0, current_player_num
    j main_game_loop
switch_to_white:
    li $t0, 2
    sw $t0, current_player_num
    j main_game_loop
    
invalid_move_msg:
    li $v0, 4
    la $a0, invalid_move
    syscall
    j get_move
end_game:
    li $v0, 4
    beq $v0, 1, print_win_black
    la $a0, win_white
    syscall
    j exit
print_win_black:
    la $a0, win_black
    syscall
exit:
    li $v0, 10
    syscall

# Print the board
print_board:
    # Print column labels
    li $v0, 4
    la $a0, col_labels
    syscall
    la $a0, newline
    li $v0, 4
    syscall
    li $t0, 8
print_board_loop:
    la $a0, row_sep
    li $v0, 4
    syscall
    li $t1, 0
    la $a0, vertical
    li $v0, 4
    syscall
print_cell_loop:
    # Check for pawn first
    mul $t2, $t0, 8
    add $t2, $t2, $t1
    subi $t2, $t2, 8
    lb $t3, board($t2)
    li $t4, 1
    beq $t3, $t4, print_x_cell
    li $t4, 2
    beq $t3, $t4, print_o_cell
    # If no pawn, check if playable
    add $t5, $t0, $t1
    lw $t6, player_color
    andi $t5, $t5, 1
    bne $t5, $t6, print_unusable_cell
    # Playable and empty
    la $a0, empty
    li $v0, 4
    syscall
    j print_next_cell
print_x_cell:
    la $a0, x_pawn
    li $v0, 4
    syscall
    j print_next_cell
print_o_cell:
    la $a0, o_pawn
    li $v0, 4
    syscall
    j print_next_cell
print_unusable_cell:
    la $a0, unusable
    li $v0, 4
    syscall
print_next_cell:
    la $a0, vertical
    li $v0, 4
    syscall
    addi $t1, $t1, 1
    blt $t1, 8, print_cell_loop
    li $v0, 1
    move $a0, $t0
    syscall
    la $a0, newline
    li $v0, 4
    syscall
    subi $t0, $t0, 1
    bnez $t0, print_board_loop
    la $a0, row_sep
    li $v0, 4
    syscall
    jr $ra

# Validate and make move
validate_and_move:
    # src_col = $a0, src_row = $a1, dst_col = $a2, dst_row = $a3
    # Calculate source and destination indices
    mul $t0, $a1, 8
    add $t0, $t0, $a0
    lb $t1, board($t0)
    
    # Check if source piece belongs to current player
    lw $t2, current_player_num
    beq $t1, $t2, valid_source
    j invalid_turn
    
valid_source:
    # Check if destination is within bounds
    blt $a2, 0, invalid
    bge $a2, 8, invalid
    blt $a3, 0, invalid
    bge $a3, 8, invalid
    
    mul $t3, $a3, 8
    add $t3, $t3, $a2
    lb $t4, board($t3)
    bnez $t4, invalid
    
    # Calculate row/col diffs
    sub $t5, $a3, $a1
    abs $t5, $t5
    sub $t6, $a2, $a0
    abs $t6, $t6
    bne $t5, $t6, invalid
    
    # Single step diagonal move
    beq $t5, 1, do_move
    
    # Capture move: must be two steps diagonal
    bne $t5, 2, invalid
    
    # Find middle square
    add $t7, $a1, $a3
    sra $t7, $t7, 1
    mul $t8, $t7, 8
    add $t9, $a0, $a2
    sra $t9, $t9, 1
    add $t8, $t8, $t9
    lb $s0, board($t8)
    
    # Middle square must have opponent's pawn
    lw $t2, current_player_num
    li $t4, 1
    beq $t2, $t4, check_white
    li $t4, 1
    bne $s0, $t4, invalid
    j do_capture
check_white:
    li $t4, 2
    bne $s0, $t4, invalid
    
do_capture:
    # Remove captured pawn
    sb $zero, board($t8)
    j do_move
    
do_move:
    # Move is valid, update board
    sb $zero, board($t0)
    lw $t2, current_player_num
    sb $t2, board($t3)
    li $v0, 1
    jr $ra
    
invalid:
    li $v0, 0
    jr $ra

check_win:
    # Returns $v0 = 1 if black wins, $v0 = 2 if white wins, 0 otherwise
    li $t0, 0
    li $t1, 0
    li $t2, 0
check_win_loop:
    lb $t3, board($t2)
    beqz $t3, check_win_next
    li $t4, 1
    beq $t3, $t4, inc_black
    li $t4, 2
    beq $t4, $t3, inc_white
check_win_next:
    addi $t2, $t2, 1
    blt $t2, 64, check_win_loop
    # If one color is gone, return winner
    beqz $t0, white_wins
    beqz $t1, black_wins
    li $v0, 0
    jr $ra
inc_black:
    addi $t0, $t0, 1
    j check_win_next
inc_white:
    addi $t1, $t1, 1
    j check_win_next
white_wins:
    li $v0, 2
    jr $ra
black_wins:
    li $v0, 1
    jr $ra

invalid_turn:
    # Print appropriate invalid turn message
    li $v0, 4
    lw $t2, current_player_num
    li $t3, 1
    beq $t2, $t3, print_invalid_p1
    la $a0, invalid_turn_p2
    syscall
    li $v0, 0
    jr $ra
print_invalid_p1:
    la $a0, invalid_turn_p1
    syscall
    li $v0, 0
    jr $ra

# New function to check for additional capture opportunities
# Input: $a0 = col, $a1 = row (current position)
# Returns: $v0 = 1 if additional capture possible, 0 if not
check_additional_capture:
    # Save return address
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Check all 4 diagonal directions for capture opportunities
    # Direction 1: up-left
    addi $a2, $a0, -2  # dst_col = src_col - 2
    addi $a3, $a1, -2  # dst_row = src_row - 2
    jal validate_and_move
    bnez $v0, capture_found
    
    # Direction 2: up-right
    addi $a2, $a0, 2   # dst_col = src_col + 2
    addi $a3, $a1, -2  # dst_row = src_row - 2
    jal validate_and_move
    bnez $v0, capture_found
    
    # Direction 3: down-left
    addi $a2, $a0, -2  # dst_col = src_col - 2
    addi $a3, $a1, 2   # dst_row = src_row + 2
    jal validate_and_move
    bnez $v0, capture_found
    
    # Direction 4: down-right
    addi $a2, $a0, 2   # dst_col = src_col + 2
    addi $a3, $a1, 2   # dst_row = src_row + 2
    jal validate_and_move
    bnez $v0, capture_found
    
    # No captures found
    li $v0, 0
    j check_additional_capture_done
    
capture_found:
    li $v0, 1
    
check_additional_capture_done:
    # Restore return address
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra

# Simplified parse_move_str to only handle single moves
parse_move_str:
    la $t0, move_str      # input pointer
    la $t1, move_coords   # output pointer
    li $t2, 0             # count
    
    # Parse first coordinate
    lb $t3, 0($t0)        # get char
    beqz $t3, parse_move_str_done
    subi $t3, $t3, 97     # 'a' -> 0
    sb $t3, 0($t1)
    addi $t0, $t0, 1
    
    lb $t4, 0($t0)
    beqz $t4, parse_move_str_done
    subi $t4, $t4, 48     # '1' -> 0
    subi $t4, $t4, 1      # 1-based to 0-based
    sb $t4, 1($t1)
    addi $t0, $t0, 1
    addi $t1, $t1, 2
    addi $t2, $t2, 1
    
    # Skip space
    lb $t3, 0($t0)
    bne $t3, 32, parse_move_str_done  # if not space, done
    addi $t0, $t0, 1
    
    # Parse second coordinate
    lb $t3, 0($t0)
    beqz $t3, parse_move_str_done
    subi $t3, $t3, 97     # 'a' -> 0
    sb $t3, 0($t1)
    addi $t0, $t0, 1
    
    lb $t4, 0($t0)
    beqz $t4, parse_move_str_done
    subi $t4, $t4, 48     # '1' -> 0
    subi $t4, $t4, 1      # 1-based to 0-based
    sb $t4, 1($t1)
    addi $t2, $t2, 1
    
parse_move_str_done:
    move $v0, $t2         # return count
    jr $ra

# New function to compare strings
# Input: $a0 = first string, $a1 = second string
# Returns: $v0 = 0 if equal, non-zero if different
strcmp:
    lb $t0, 0($a0)      # Load first char of first string
    lb $t1, 0($a1)      # Load first char of second string
    
    # Check for newline or null terminator
    beq $t0, 10, strcmp_check_second  # If newline, check if second string is done
    beq $t0, 13, strcmp_check_second  # If carriage return, check if second string is done
    beq $t0, 0, strcmp_check_second   # If null terminator, check if second string is done
    
    bne $t0, $t1, strcmp_diff  # If different, return non-zero
    beqz $t1, strcmp_same  # If second string is done, strings are equal
    addi $a0, $a0, 1    # Move to next char
    addi $a1, $a1, 1
    j strcmp

strcmp_check_second:
    # If we hit end of first string, check if second string is also done
    beqz $t1, strcmp_same
    j strcmp_diff

strcmp_same:
    li $v0, 0
    jr $ra
strcmp_diff:
    li $v0, 1
    jr $ra