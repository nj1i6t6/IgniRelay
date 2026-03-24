import fitz  # PyMuPDF
import sys
import os

def pdf_to_text(pdf_path, txt_path):
    print(f"Extracting {pdf_path} to {txt_path}...")
    try:
        doc = fitz.open(pdf_path)
        with open(txt_path, "w", encoding="utf-8") as out:
            for page in doc:
                text = page.get_text()
                out.write(text)
                out.write("\n\n---\n\n")
        print(f"Successfully extracted: {txt_path}")
    except Exception as e:
        print(f"Failed to extract {pdf_path}: {e}")

if __name__ == "__main__":
    pdf_files = [
        "c:/Users/radio/Downloads/IDE/CoReM/docs/烽傳_IgniRelay_技術白皮書_v1.0.pdf",
        "c:/Users/radio/Downloads/IDE/CoReM/docs/烽傳_IgniRelay_App技術說明_v1.0.pdf"
    ]
    os.makedirs("c:/Users/radio/Downloads/IDE/CoReM/tmp", exist_ok=True)
    
    for pdf in pdf_files:
        filename = os.path.basename(pdf).replace(".pdf", ".txt")
        txt_path = os.path.join("c:/Users/radio/Downloads/IDE/CoReM/tmp", filename)
        pdf_to_text(pdf, txt_path)
