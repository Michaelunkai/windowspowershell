<#
.SYNOPSIS
    summ
#>
# Navigate to the backup directory and ensure the virtual environment is set up
    Set-Location -Path "F:\\backup\windowsapps"
    if (-Not (Test-Path ".\venv")) {
        python -m venv venv
    }
    .\venv\Scripts\Activate.ps1
    # Change to the specific project directory
    Set-Location -Path "F:\\\study\\Dev_Toolchain\\programming\python\apps\youtube\youtube_summarizer\C"
    # Set the OpenAI API Key
    $Env:OPENAI_API_KEY = "sk-svcacct-TiI2B_7zM1_B8PISYuPQhZTzNAtJRGvhEAtmDqCGE9VtuxGvMJBYnus_nbuoeT3BlbkFJUupZffoO1GXpkhv-o1PlCY1vrqoRdmuFSIqPt2opMT-AB1MdxfO63z6RIhX7wA"
    # Run Streamlit using the absolute path
    F:\\backup\windowsapps\venv\Scripts\streamlit.exe run a.py
