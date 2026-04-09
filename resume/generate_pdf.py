#!/usr/bin/env python3
"""Generate PDF resume from Markdown using ReportLab"""

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.lib.colors import HexColor
import re

# Read markdown
with open(r'F:\study\resume\resume_enhanced.md', 'r', encoding='utf-8') as f:
    content = f.read()

# Create PDF
pdf_path = r'F:\study\resume\Till_Thelet_Resume.pdf'
doc = SimpleDocTemplate(pdf_path, pagesize=A4,
                        leftMargin=1.5*cm, rightMargin=1.5*cm,
                        topMargin=1.5*cm, bottomMargin=1.5*cm)

# Styles
styles = getSampleStyleSheet()

title_style = ParagraphStyle(
    'CustomTitle',
    parent=styles['Heading1'],
    fontSize=24,
    textColor=HexColor('#1a1a1a'),
    spaceAfter=6,
    alignment=TA_CENTER
)

subtitle_style = ParagraphStyle(
    'CustomSubtitle',
    parent=styles['Normal'],
    fontSize=10,
    textColor=HexColor('#666666'),
    alignment=TA_CENTER,
    spaceAfter=12
)

heading_style = ParagraphStyle(
    'CustomHeading',
    parent=styles['Heading2'],
    fontSize=13,
    textColor=HexColor('#1a1a1a'),
    spaceBefore=12,
    spaceAfter=6,
    borderColor=HexColor('#2563eb'),
    borderWidth=2,
    borderPadding=2
)

subheading_style = ParagraphStyle(
    'CustomSubheading',
    parent=styles['Heading3'],
    fontSize=11,
    textColor=HexColor('#1a1a1a'),
    spaceBefore=8,
    spaceAfter=3,
    fontName='Helvetica-Bold'
)

body_style = ParagraphStyle(
    'CustomBody',
    parent=styles['Normal'],
    fontSize=10,
    leading=14,
    spaceAfter=6
)

bullet_style = ParagraphStyle(
    'CustomBullet',
    parent=styles['Normal'],
    fontSize=10,
    leading=14,
    leftIndent=20,
    spaceAfter=3,
    bulletIndent=10
)

# Parse content
story = []
lines = content.split('\n')

for line in lines:
    line = line.strip()
    
    # Skip empty lines and separators
    if not line or line == '---':
        story.append(Spacer(1, 0.2*cm))
        continue
    
    # Title (H1)
    if line.startswith('# '):
        text = line[2:]
        story.append(Paragraph(text, title_style))
    
    # Section headers (H2)
    elif line.startswith('## '):
        text = line[3:]
        story.append(Paragraph(f'<b>{text}</b>', heading_style))
    
    # Subsection headers (H3)
    elif line.startswith('### '):
        text = line[4:]
        story.append(Paragraph(f'<b>{text}</b>', subheading_style))
    
    # Bullet points
    elif line.startswith('- '):
        text = line[2:]
        # Convert markdown bold to HTML
        text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)
        story.append(Paragraph(f'• {text}', bullet_style))
    
    # Regular paragraphs
    else:
        # Convert markdown formatting
        text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', line)
        text = re.sub(r'\[(.+?)\]\((.+?)\)', r'<link href="\2">\1</link>', text)
        
        # Skip markdown table headers
        if '|' in text or text.startswith('*'):
            continue
            
        if text:
            story.append(Paragraph(text, body_style))

# Build PDF
doc.build(story)
print(f"PDF created: {pdf_path}")
