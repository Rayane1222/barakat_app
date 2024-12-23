from fastapi import FastAPI
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import ollama

# Ollama API endpoint
OLLAMA_API_ENDPOINT = "http://localhost:11434"
MODEL_ID = "llama3"

# Initialize the Ollama client with the custom endpoint
client = ollama.Client(host=OLLAMA_API_ENDPOINT)

app = FastAPI()

# Define a request model
class ChatRequest(BaseModel):
    message: str

@app.post("/chat")
async def chat(request: ChatRequest):
    user_message = request.message
    messages = [{"role": "user", "content": user_message}]
    
    # Generate response from Ollama
    full_response = ""
    try:
        for response in client.chat(model=MODEL_ID, messages=messages, stream=False):
            print("Response from client.chat:", response)  # Debugging line
            
            # Check if response is a tuple
            if isinstance(response, tuple):
                # Check if the last element contains the 'message'
                if response[0] == 'message':
                    assistant_message = response[1].content  # Get the content of the Message object
                    full_response += assistant_message  # Append the assistant's message to the response
                    break  # Exit the loop after getting the message
            
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

    return JSONResponse(content={"response": full_response})

    #uvicorn app_fastapi:app --reload