
with open(r'c:\Users\toopt\Desktop\meto\lib\screens\voice_room_screen.dart', 'rb') as f:
    content = f.read()
    # Check for non-ascii characters in the first 1000 bytes
    for i, b in enumerate(content[:2000]):
        if b > 127:
            print(f"Non-ascii at byte {i}: {b} ({chr(b)})")
