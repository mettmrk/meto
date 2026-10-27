def count_braces(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    stack = []
    for i, line in enumerate(lines):
        for j, char in enumerate(line):
            if char == '{':
                stack.append((i + 1, j + 1))
            elif char == '}':
                if not stack:
                    return f"Extra closing brace at line {i+1}, col {j+1}"
                stack.pop()
    
    if stack:
        return f"Unclosed opening brace(s) starting at: {stack}"
    return "Braces are balanced."

print(count_braces(r'c:\Users\toopt\Desktop\meto\lib\screens\voice_room_screen.dart'))
