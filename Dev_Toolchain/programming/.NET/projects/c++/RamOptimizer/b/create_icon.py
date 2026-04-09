from PIL import Image, ImageDraw

# Create a 256x256 image with transparency
size = 256
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Colors - modern blue/cyan theme
bg_color = (33, 150, 243, 255)  # Material blue
accent_color = (0, 188, 212, 255)  # Cyan
highlight = (255, 255, 255, 255)  # White

# Draw a rounded rectangle background
margin = 20
draw.rounded_rectangle(
    [(margin, margin), (size-margin, size-margin)],
    radius=40,
    fill=bg_color
)

# Draw RAM chip shape - simplified memory module
chip_margin = 60
chip_width = size - 2 * chip_margin
chip_height = 120
chip_top = size // 2 - chip_height // 2

# Main chip body
draw.rectangle(
    [(chip_margin, chip_top), (size-chip_margin, chip_top + chip_height)],
    fill=accent_color
)

# Memory pins at the bottom
pin_count = 8
pin_width = 10
pin_height = 15
pin_spacing = (chip_width - pin_count * pin_width) // (pin_count + 1)

for i in range(pin_count):
    x = chip_margin + pin_spacing + i * (pin_width + pin_spacing)
    y = chip_top + chip_height
    draw.rectangle(
        [(x, y), (x + pin_width, y + pin_height)],
        fill=highlight
    )

# Draw memory blocks on the chip
block_margin = 10
block_count = 4
block_height = 15
block_spacing = (chip_height - 2 * block_margin - block_count * block_height) // (block_count - 1)

for i in range(block_count):
    y = chip_top + block_margin + i * (block_height + block_spacing)
    draw.rectangle(
        [(chip_margin + block_margin, y),
         (size - chip_margin - block_margin, y + block_height)],
        fill=(255, 255, 255, 200)
    )

# Draw optimization indicator - upward arrow or checkmark
arrow_size = 40
arrow_x = size // 2
arrow_y = chip_top - 50

# Simple upward arrow
draw.polygon(
    [
        (arrow_x, arrow_y - arrow_size),  # Top
        (arrow_x - arrow_size//2, arrow_y),  # Bottom left
        (arrow_x - arrow_size//4, arrow_y),  # Inner left
        (arrow_x - arrow_size//4, arrow_y + arrow_size//2),  # Stem left
        (arrow_x + arrow_size//4, arrow_y + arrow_size//2),  # Stem right
        (arrow_x + arrow_size//4, arrow_y),  # Inner right
        (arrow_x + arrow_size//2, arrow_y),  # Bottom right
    ],
    fill=(76, 175, 80, 255)  # Green
)

# Save as ICO with multiple sizes
sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)]
images = []

for ico_size in sizes:
    resized = img.resize(ico_size, Image.Resampling.LANCZOS)
    images.append(resized)

# Save the icon
images[0].save(
    'ram_optimizer.ico',
    format='ICO',
    sizes=[(img.width, img.height) for img in images],
    append_images=images[1:]
)

print("Icon created successfully: ram_optimizer.ico")
