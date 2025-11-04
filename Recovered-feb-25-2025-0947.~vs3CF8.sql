# app.py
from flask import Flask, render_template, request, jsonify
import openai
import os

# Initialize Flask app
app = Flask(__name__)

# Set your OpenAI API key
openai.api_key = os.getenv("OPENAI_API_KEY")  # Make sure to set this in your environment

# Route for homepage
@app.route("/")
def index():
    return render_template("index.html")

# Route to handle AI requests
@app.route("/ask", methods=["POST"])
def ask():
    user_input = request.json.get("question")
    
    if not user_input:
        return jsonify({"error": "No question provided"}), 400
    
    try:
        # Call OpenAI API
        response = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": "You are a helpful AI assistant."},
                {"role": "user", "content": user_input}
            ],
            max_tokens=200
        )
        answer = response.choices[0].message['content'].strip()
        return jsonify({"answer": answer})
    
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(debug=True)
pip install flask openai
export OPENAI_API_KEY="your_api_key_here"  # Linux/macOS
setx OPENAI_API_KEY "your_api_key_here"     # Windows
python app.py
ai_website/
├─ app.py
├─ models.py
├─ database.db
├─ templates/
│   ├─ index.html
│   └─ login.html
├─ static/
│   └─ script.js
├─ requirements.txt
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    password = db.Column(db.String(100), nullable=False)  # Store hashed passwords

class ChatHistory(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    question = db.Column(db.Text, nullable=False)
    answer = db.Column(db.Text, nullable=False)
from flask import Flask, render_template, request, jsonify, redirect, url_for, session
from flask_sqlalchemy import SQLAlchemy
from werkzeug.security import generate_password_hash, check_password_hash
import openai
import os
from models import db, User, ChatHistory

# Flask setup
app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "supersecret")
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///database.db'
db.init_app(app)

openai.api_key = os.getenv("OPENAI_API_KEY")

# Create database tables
with app.app_context():
    db.create_all()

# Login page
@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form['username']
        password = request.form['password']
        user = User.query.filter_by(username=username).first()
        if user and check_password_hash(user.password, password):
            session['user_id'] = user.id
            return redirect(url_for('index'))
        return "Invalid credentials"
    return render_template("login.html")

# Register page
@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        username = request.form['username']
        password = generate_password_hash(request.form['password'])
        new_user = User(username=username, password=password)
        db.session.add(new_user)
        db.session.commit()
        return redirect(url_for('login'))
    return render_template("login.html")

# Home page
@app.route("/")
def index():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    return render_template("index.html")

# AI endpoint
@app.route("/ask", methods=["POST"])
def ask():
    if 'user_id' not in session:
        return jsonify({"error": "Not authenticated"}), 401

    user_input = request.json.get("question")
    if not user_input:
        return jsonify({"error": "No question provided"}), 400

    try:
        # Call OpenAI API
        response = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role": "system", "content": "You are a helpful AI assistant."},
                      {"role": "user", "content": user_input}],
            max_tokens=200
        )
        answer = response.choices[0].message['content'].strip()

        # Save chat history
        chat = ChatHistory(user_id=session['user_id'], question=user_input, answer=answer)
        db.session.add(chat)
        db.session.commit()

        return jsonify({"answer": answer})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Analytics endpoint
@app.route("/analytics")
def analytics():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    chats = ChatHistory.query.filter_by(user_id=session['user_id']).all()
    total_questions = len(chats)
    # Example: most common words
    from collections import Counter
    words = Counter()
    for chat in chats:
        words.update(chat.question.split())
    top_words = words.most_common(5)

    return jsonify({"total_questions": total_questions, "top_words": top_words})

if __name__ == "__main__":
    app.run(debug=True)
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>AI Assistant</title>
<style>
    body { font-family: Arial; max-width: 600px; margin: 50px auto; }
    #chat { border: 1px solid #ccc; padding: 20px; height: 400px; overflow-y: scroll; }
    .message { margin: 10px 0; }
    .user { color: blue; }
    .ai { color: green; }
</style>
</head>
<body>
<h1>AI Assistant</h1>
<div id="chat"></div>
<input type="text" id="userInput" placeholder="Ask me anything...">
<button id="sendBtn">Send</button>
<script>
const chat = document.getElementById("chat");
const input = document.getElementById("userInput");
const button = document.getElementById("sendBtn");

button.onclick = async () => {
    const question = input.value;
    if (!question) return;

    const userMsg = document.createElement("div");
    userMsg.classList.add("message", "user");
    userMsg.textContent = "You: " + question;
    chat.appendChild(userMsg);
    input.value = "";

    const response = await fetch("/ask", {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({question})
    });
    const data = await response.json();

    const aiMsg = document.createElement("div");
    aiMsg.classList.add("message", "ai");
    aiMsg.textContent = "AI: " + (data.answer || data.error);
    chat.appendChild(aiMsg);
    chat.scrollTop = chat.scrollHeight;
};
</script>
</body>
</html>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>AI Voice Assistant</title>
<style>
    body { font-family: Arial; max-width: 600px; margin: 50px auto; }
    #chat { border: 1px solid #ccc; padding: 20px; height: 400px; overflow-y: scroll; }
    .message { margin: 10px 0; }
    .user { color: blue; }
    .ai { color: green; }
    #voiceBtn { margin-left: 10px; }
</style>
</head>
<body>
<h1>AI Voice Assistant</h1>
<div id="chat"></div>
<input type="text" id="userInput" placeholder="Ask me anything...">
<button id="sendBtn">Send</button>
<button id="voiceBtn">🎤 Speak</button>

<script>
const chat = document.getElementById("chat");
const input = document.getElementById("userInput");
const sendBtn = document.getElementById("sendBtn");
const voiceBtn = document.getElementById("voiceBtn");

// Function to speak text
function speak(text) {
    const utterance = new Speech
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI Voice Assistant</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 600px;
      margin: 50px auto;
      text-align: center;
    }
    #chat {
      border: 1px solid #ccc;
      padding: 15px;
      height: 400px;
      overflow-y: auto;
      margin-bottom: 20px;
    }
    .message {
      margin: 10px 0;
    }
    .user { color: blue; }
    .ai { color: green; }
    button {
      padding: 10px 20px;
      margin: 5px;
    }
  </style>
</head>
<body>
  <h1>AI Voice Assistant</h1>
  <div id="chat"></div>

  <input type="text" id="userInput" placeholder="Type a message..." />
  <button id="sendBtn">Send</button>
  <button id="voiceBtn">🎤 Speak</button>

  <script>
    const chat = document.getElementById('chat');
    const userInput = document.getElementById('userInput');
    const sendBtn = document.getElementById('sendBtn');
    const voiceBtn = document.getElementById('voiceBtn');

    // Add message to chat
    function addMessage(text, sender) {
      const div = document.createElement('div');
      div.className = `message ${sender}`;
      div.textContent = text;
      chat.appendChild(div);
      chat.scrollTop = chat.scrollHeight;
    }

    // Text-to-speech for AI responses
    function speak(text) {
      const utterance = new SpeechSynthesisUtterance(text);
      speechSynthesis.speak(utterance);
    }

    // Simulated AI response (replace with real API call)
    async function getAIResponse(message) {
      // Example placeholder logic
      return `You said: "${message}"`;
    }

    // Handle sending message
    async function sendMessage() {
      const message = userInput.value.trim();
      if (!message) return;
      addMessage(message, 'user');
      userInput.value = '';
      const response = await getAIResponse(message);
      addMessage(response, 'ai');
      speak(response);
    }

    sendBtn.addEventListener('click', sendMessage);
    userInput.addEventListener('keypress', e => {
      if (e.key === 'Enter') sendMessage();
    });

    // Voice input
    voiceBtn.addEventListener('click', () => {
      if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
        alert('Speech Recognition not supported in this browser.');
        return;
      }

      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      const recognition = new SpeechRecognition();
      recognition.lang = 'en-US';
      recognition.interimResults = false;
      recognition.maxAlternatives = 1;

      recognition.start();

      recognition.onresult = async (event) => {
        const transcript = event.results[0][0].transcript;
        addMessage(transcript, 'user');
        const response = await getAIResponse(transcript);
        addMessage(response, 'ai');
        speak(response);
      };

      recognition.onerror = (event) => {
        console.error('Speech recognition error', event.error);
      };
    });
  </script>
</body>
</html>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Continuous AI Voice Assistant</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 600px;
      margin: 50px auto;
      text-align: center;
    }
    #chat {
      border: 1px solid #ccc;
      padding: 15px;
      height: 400px;
      overflow-y: auto;
      margin-bottom: 20px;
    }
    .message {
      margin: 10px 0;
    }
    .user { color: blue; }
    .ai { color: green; }
  </style>
</head>
<body>
  <h1>Continuous AI Voice Assistant</h1>
  <div id="chat"></div>

  <input type="text" id="userInput" placeholder="Type a message..." />
  <button id="sendBtn">Send</button>

  <script>
    const chat = document.getElementById('chat');
    const userInput = document.getElementById('userInput');
    const sendBtn = document.getElementById('sendBtn');

    function addMessage(text, sender) {
      const div = document.createElement('div');
      div.className = `message ${sender}`;
      div.textContent = text;
      chat.appendChild(div);
      chat.scrollTop = chat.scrollHeight;
    }

    function speak(text) {
      return new Promise(resolve => {
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.onend = resolve;
        speechSynthesis.speak(utterance);
      });
    }

    async function getAIResponse(message) {
      // Placeholder AI logic, replace with real API call
      return `You said: "${message}"`;
    }

    async function sendMessage(message) {
      if (!message) return;
      addMessage(message, 'user');
      const response = await getAIResponse(message);
      addMessage(response, 'ai');
      await speak(response);
    }

    sendBtn.addEventListener('click', () => {
      const message = userInput.value.trim();
      userInput.value = '';
      sendMessage(message);
    });

    userInput.addEventListener('keypress', e => {
      if (e.key === 'Enter') {
        const message = userInput.value.trim();
        userInput.value = '';
        sendMessage(message);
      }
    });

    // Continuous voice recognition
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      alert('Speech Recognition not supported in this browser.');
    } else {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      const recognition = new SpeechRecognition();
      recognition.lang = 'en-US';
      recognition.interimResults = false;
      recognition.maxAlternatives = 1;
      recognition.continuous = false;

      recognition.onresult = async (event) => {
        const transcript = event.results[0][0].transcript;
        await sendMessage(transcript);
        recognition.start(); // restart listening after speaking
      };

      recognition.onerror = (event) => {
        console.error('Speech recognition error', event.error);
        recognition.start(); // restart on error
      };

      recognition.onend = () => {
        // Restart recognition if it stops unexpectedly
        recognition.start();
      };

      recognition.start(); // start listening immediately
    }
  </script>
</body>
</html>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Advanced AI Voice Assistant</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 600px;
      margin: 50px auto;
      text-align: center;
    }
    #chat {
      border: 1px solid #ccc;
      padding: 15px;
      height: 400px;
      overflow-y: auto;
      margin-bottom: 20px;
    }
    .message {
      margin: 10px 0;
    }
    .user { color: blue; }
    .ai { color: green; }
  </style>
</head>
<body>
  <h1>Advanced AI Voice Assistant</h1>
  <div id="chat"></div>

  <input type="text" id="userInput" placeholder="Type a message..." />
  <button id="sendBtn">Send</button>

  <script>
    const chat = document.getElementById('chat');
    const userInput = document.getElementById('userInput');
    const sendBtn = document.getElementById('sendBtn');

    function addMessage(text, sender) {
      const div = document.createElement('div');
      div.className = `message ${sender}`;
      div.textContent = text;
      chat.appendChild(div);
      chat.scrollTop = chat.scrollHeight;
    }

    function speak(text) {
      return new Promise(resolve => {
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.onend = resolve;
        speechSynthesis.speak(utterance);
      });
    }

    async function getAIResponse(message) {
      // Placeholder AI logic: replace with your API call
      return `You said: "${message}"`;
    }

    async function handleMessage(message) {
      addMessage(message, 'user');
      const response = await getAIResponse(message);
      addMessage(response, 'ai');
      await speak(response);
    }

    sendBtn.addEventListener('click', () => {
      const message = userInput.value.trim();
      if (!message) return;
      userInput.value = '';
      handleMessage(message);
    });

    userInput.addEventListener('keypress', e => {
      if (e.key === 'Enter') {
        const message = userInput.value.trim();
        if (!message) return;
        userInput.value = '';
        handleMessage(message);
      }
    });

    // Continuous and overlapping voice recognition
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      alert('Speech Recognition not supported in this browser.');
    } else {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      const recognition = new SpeechRecognition();
      recognition.lang = 'en-US';
      recognition.interimResults = true; // get partial results while speaking
      recognition.maxAlternatives = 1;
      recognition.continuous = true;

      let isSpeaking = false;

      recognition.onresult = (event) => {
        let transcript = '';
        for (let i = event.resultIndex; i < event.results.length; i++) {
          transcript += event.results[i][0].transcript;
        }

        // Only process when final result
        if (event.results[event.results.length - 1].isFinal) {
          if (!isSpeaking) {
            isSpeaking = true;
            handleMessage(transcript).finally(() => {
              isSpeaking = false;
            });
          }
        }
      };

      recognition.onerror = (event) => {
        console.error('Speech recognition error', event.error);
      };

      recognition.start();
      recognition.onend = () => {
        recognition.start(); // auto-restart recognition
      };
    }
  </script>
</body>
</html>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Parallel AI Voice Assistant</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 600px;
      margin: 50px auto;
      text-align: center;
    }
    #chat {
      border: 1px solid #ccc;
      padding: 15px;
      height: 400px;
      overflow-y: auto;
      margin-bottom: 20px;
    }
    .message {
      margin: 10px 0;
    }
    .user { color: blue; }
    .ai { color: green; }
  </style>
</head>
<body>
  <h1>Parallel AI Voice Assistant</h1>
  <div id="chat"></div>

  <input type="text" id="userInput" placeholder="Type a message..." />
  <button id="sendBtn">Send</button>

  <script>
    const chat = document.getElementById('chat');
    const userInput = document.getElementById('userInput');
    const sendBtn = document.getElementById('sendBtn');

    function addMessage(text, sender) {
      const div = document.createElement('div');
      div.className = `message ${sender}`;
      div.textContent = text;
      chat.appendChild(div);
      chat.scrollTop = chat.scrollHeight;
    }

    async function getAIResponse(message) {
      // Placeholder AI logic; replace with real API call
      return `You said: "${message}"`;
    }

    async function handleMessage(message) {
      addMessage(message, 'user');
      const response = await getAIResponse(message);
      addMessage(response, 'ai');
      speak(response); // fire-and-forget; recognition continues
    }

    function speak(text) {
      const utterance = new SpeechSynthesisUtterance(text);
      speechSynthesis.speak(utterance);
    }

    sendBtn.addEventListener('click', () => {
      const message = userInput.value.trim();
      if (!message) return;
      userInput.value = '';
      handleMessage(message);
    });

    userInput.addEventListener('keypress', e => {
      if (e.key === 'Enter') {
        const message = userInput.value.trim();
        if (!message) return;
        userInput.value = '';
        handleMessage(message);
      }
    });

    // Parallel speech recognition
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      alert('Speech Recognition not supported in this browser.');
    } else {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      const recognition = new SpeechRecognition();
      recognition.lang = 'en-US';
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;
      recognition.continuous = true;

      recognition.onresult = (event) => {
        let transcript = '';
        for (let i = event.resultIndex; i < event.results.length; i++) {
          transcript += event.results[i][0].transcript;
        }

        if (event.results[event.results.length - 1].isFinal) {
          handleMessage(transcript);
        }
      };

      recognition.onerror = (event) => {
        console.error('Speech recognition error', event.error);
      };

      recognition.onend = () => {
        recognition.start(); // always restart listening
      };

      recognition.start();
    }
  </script>
</body>
</html>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Queued AI Voice Assistant</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 600px;
      margin: 50px auto;
      text-align: center;
    }
    #chat {
      border: 1px solid #ccc;
      padding: 15px;
      height: 400px;
      overflow-y: auto;
      margin-bottom: 20px;
    }
    .message {
      margin: 10px 0;
    }
    .user { color: blue; }
    .ai { color: green; }
  </style>
</head>
<body>
  <h1>Queued AI Voice Assistant</h1>
  <div id="chat"></div>

  <input type="text" id="userInput" placeholder="Type a message..." />
  <button id="sendBtn">Send</button>

  <script>
    const chat = document.getElementById('chat');
    const userInput = document.getElementById('userInput');
    const sendBtn = document.getElementById('sendBtn');

    const messageQueue = [];
    let processingQueue = false;

    function addMessage(text, sender) {
      const div = document.createElement('div');
      div.className = `message ${sender}`;
      div.textContent = text;
      chat.appendChild(div);
      chat.scrollTop = chat.scrollHeight;
    }

    async function getAIResponse(message) {
      // Replace with your real API call
      return `You said: "${message}"`;
    }

    async function processQueue() {
      if (processingQueue || messageQueue.length === 0) return;
      processingQueue = true;

      while (messageQueue.length > 0) {
        const message = messageQueue.shift();
        addMessage(message, 'user');
        const response = await getAIResponse(message);
        addMessage(response, 'ai');
        await speak(response);
      }

      processingQueue = false;
    }

    function enqueueMessage(message) {
      messageQueue.push(message);
      processQueue();
    }

    function speak(text) {
      return new Promise(resolve => {
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.onend = resolve;
        speechSynthesis.speak(utterance);
      });
    }

    sendBtn.addEventListener('click', () => {
      const message = userInput.value.trim();
      if (!message) return;
      userInput.value = '';
      enqueueMessage(message);
    });

    userInput.addEventListener('keypress', e => {
      if (e.key === 'Enter') {
        const message = userInput.value.trim();
        if (!message) return;
        userInput.value = '';
        enqueueMessage(message);
      }
    });

    // Continuous speech recognition
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      alert('Speech Recognition not supported in this browser.');
    } else {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      const recognition = new SpeechRecognition();
      recognition.lang = 'en-US';
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;
      recognition.continuous = true;

      recognition.onresult = (event) => {
        let transcript = '';
        for (let i = event.resultIndex; i < event.results.length; i++) {
          transcript += event.results[i][0].transcript;
        }

        if (event.results[event.results.length - 1].isFinal) {
          enqueueMessage(transcript);
        }
      };

      recognition.onerror = (event) => {
        console.error('Speech recognition error', event.error);
      };

      recognition.onend = () => {
        recognition.start(); // auto-restart
      };

      recognition.start();
    }
  </script>
</body>
</html>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>AI Voice Assistant with Indicators</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 600px;
      margin: 50px auto;
      text-align: center;
    }
    #chat {
      border: 1px solid #ccc;
      padding: 15px;
      height: 400px;
      overflow-y: auto;
      margin-bottom: 20px;
    }
    .message {
      margin: 10px 0;
    }
    .user { color: blue; }
    .ai { color: green; }
    #status {
      margin-bottom: 10px;
      font-weight: bold;
    }
    .listening { color: orange; }
    .speaking { color: green; }
  </style>
</head>
<body>
  <h1>AI Voice Assistant</h1>
  <div id="status">Initializing...</div>
  <div id="chat"></div>

  <input type="text" id="userInput" placeholder="Type a message..." />
  <button id="sendBtn">Send</button>

  <script>
    const chat = document.getElementById('chat');
    const userInput = document.getElementById('userInput');
    const sendBtn = document.getElementById('sendBtn');
    const status = document.getElementById('status');

    const messageQueue = [];
    let processingQueue = false;

    function addMessage(text, sender) {
      const div = document.createElement('div');
      div.className = `message ${sender}`;
      div.textContent = text;
      chat.appendChild(div);
      chat.scrollTop = chat.scrollHeight;
    }

    async function getAIResponse(message) {
      // Replace with your real API call
      return `You said: "${message}"`;
    }

    async function processQueue() {
      if (processingQueue || messageQueue.length === 0) return;
      processingQueue = true;

      while (messageQueue.length > 0) {
        const message = messageQueue.shift();
        addMessage(message, 'user');
        const response = await getAIResponse(message);
        addMessage(response, 'ai');
        status.textContent = '💬 Speaking...';
        status.className = 'speaking';
        await speak(response);
        status.textContent = '🎤 Listening...';
        status.className = 'listening';
      }

      processingQueue = false;
    }

    function enqueueMessage(message) {
      messageQueue.push(message);
      processQueue();
    }

    function speak(text) {
      return new Promise(resolve => {
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.onend = resolve;
        speechSynthesis.speak(utterance);
      });
    }

    sendBtn.addEventListener('click', () => {
      const message = userInput.value.trim();
      if (!message) return;
      userInput.value = '';
      enqueueMessage(message);
    });

    userInput.addEventListener('keypress', e => {
      if (e.key === 'Enter') {
        const message = userInput.value.trim();
        if (!message) return;
        userInput.value = '';
        enqueueMessage(message);
      }
    });

    // Speech recognition
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      alert('Speech Recognition not supported in this browser.');
      status.textContent = '⚠️ Not supported';
    } else {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      const recognition = new SpeechRecognition();
      recognition.lang = 'en-US';
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;
      recognition.continuous = true;

      status.textContent = '🎤 Listening...';
      status.className = 'listening';

      recognition.onresult = (event) => {
        let transcript = '';
        for (let i = event.resultIndex; i < event.results.length; i++) {
          transcript += event.results[i][0].transcript;
        }

        if (event.results[event.results.length - 1].isFinal) {
          enqueueMessage(transcript);
        }
      };

      recognition.onerror = (event) => {
        console.error('Speech recognition error', event.error);
        status.textContent = '⚠️ Error';
      };

      recognition.onend = () => {
        recognition.start(); // auto-restart
      };

      recognition.start();
    }
  </script>
</body>
</html>
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Animated AI Voice Assistant</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      max-width: 600px;
      margin: 50px auto;
      text-align: center;
    }

    #chat {
      border: 1px solid #ccc;
      padding: 15px;
      height: 400px;
      overflow-y: auto;
      margin-bottom: 20px;
    }

    .message {
      margin: 10px 0;
    }

    .user { color: blue; }
    .ai { color: green; }

    #status {
      margin-bottom: 15px;
      font-weight: bold;
      display: flex;
      justify-content: center;
      align-items: center;
      gap: 10px;
      font-size: 1.2em;
    }

    .icon {
      width: 24px;
      height: 24px;
    }

    /* Listening animation */
    .listening .icon {
      background-color: orange;
      border-radius: 50%;
      animation: pulse 1s infinite;
    }

    /* Speaking animation */
    .speaking .icon {
      background-color: green;
      border-radius: 50%;
      animation: pulse 0.6s infinite;
    }

    @keyframes pulse {
      0% { transform: scale(1); opacity: 0.7; }
      50% { transform: scale(1.5); opacity: 1; }
      100% { transform: scale(1); opacity: 0.7; }
    }
  </style>
</head>
<body>
  <h1>Animated AI Voice Assistant</h1>
  <div id="status">
    <div class="icon"></div>
    <span id="statusText">Initializing...</span>
  </div>
  <div id="chat"></div>

  <input type="text" id="userInput" placeholder="Type a message..." />
  <button id="sendBtn">Send</button>

  <script>
    const chat = document.getElementById('chat');
    const userInput = document.getElementById('userInput');
    const sendBtn = document.getElementById('sendBtn');
    const status = document.getElementById('status');
    const statusText = document.getElementById('statusText');

    const messageQueue = [];
    let processingQueue = false;

    function addMessage(text, sender) {
      const div = document.createElement('div');
      div.className = `message ${sender}`;
      div.textContent = text;
      chat.appendChild(div);
      chat.scrollTop = chat.scrollHeight;
    }

    async function getAIResponse(message) {
      // Replace with real API call
      return `You said: "${message}"`;
    }

    async function processQueue() {
      if (processingQueue || messageQueue.length === 0) return;
      processingQueue = true;

      while (messageQueue.length > 0) {
        const message = messageQueue.shift();
        addMessage(message, 'user');
        const response = await getAIResponse(message);
        addMessage(response, 'ai');

        // Update status to speaking
        status.className = 'speaking';
        statusText.textContent = '💬 Speaking...';
        await speak(response);

        // Update status back to listening
        status.className = 'listening';
        statusText.textContent = '🎤 Listening...';
      }

      processingQueue = false;
    }

    function enqueueMessage(message) {
      messageQueue.push(message);
      processQueue();
    }

    function speak(text) {
      return new Promise(resolve => {
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.onend = resolve;
        speechSynthesis.speak(utterance);
      });
    }

    sendBtn.addEventListener('click', () => {
      const message = userInput.value.trim();
      if (!message) return;
      userInput.value = '';
      enqueueMessage(message);
    });

    userInput.addEventListener('keypress', e => {
      if (e.key === 'Enter') {
        const message = userInput.value.trim();
        if (!message) return;
        userInput.value = '';
        enqueueMessage(message);
      }
    });

    // Speech recognition
    if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
      alert('Speech Recognition not supported in this browser.');
      statusText.textContent = '⚠️ Not supported';
    } else {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      const recognition = new SpeechRecognition();
      recognition.lang = 'en-US';
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;
      recognition.continuous = true;

      // Initialize status
      status.className = 'listening';
      statusText.textContent = '🎤 Listening...';

      recognition.onresult = (event) => {
        let transcript = '';
        for (let i = event.resultIndex; i < event.results.length; i++) {
          transcript += event.results[i][0].transcript;
        }

        if (event.results[event.results.length - 1].isFinal) {
          enqueueMessage(transcript);
        }
      };

      recognition.onerror = (event) => {
        console.error('Speech recognition error', event.error);
        statusText.textContent = '⚠️ Error';
      };

      recognition.onend = () => {
        recognition.start(); // auto-restart
      };

      recognition.start();
    }
  </script>
</body>
</html>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Ultimate AI Voice Assistant</title>
<style>
  body {
    font-family: Arial, sans-serif;
    max-width: 600px;
    margin: 50px auto;
    text-align: center;
    background: #f0f2f5;
  }

  #chat {
    border: 1px solid #ccc;
    padding: 15px;
    height: 350px;
    overflow-y: auto;
    margin-bottom: 15px;
    background: #fff;
    border-radius: 10px;
  }

  .message { margin: 10px 0; }
  .user { color: #1a73e8; }
  .ai { color: #0f9d58; }

  #status {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 15px;
    font-size: 1.2em;
    margin-bottom: 15px;
  }

  .icon {
    width: 24px;
    height: 24px;
    border-radius: 50%;
  }

  .listening .icon {
    background-color: orange;
    animation: pulse 1s infinite;
  }

  .speaking .icon {
    background-color: green;
    animation: pulse 0.6s infinite;
  }

  @keyframes pulse {
    0% { transform: scale(1); opacity: 0.7; }
    50% { transform: scale(1.5); opacity: 1; }
    100% { transform: scale(1); opacity: 0.7; }
  }

  #waveform {
    width: 100%;
    height: 50px;
    background: #222;
    border-radius: 5px;
    margin-bottom: 15px;
  }

  input, button {
    padding: 10px;
    font-size: 1em;
    margin: 5px;
    border-radius: 5px;
  }

  button {
    cursor: pointer;
  }
</style>
</head>
<body>
<h1>Ultimate AI Voice Assistant</h1>
<div id="status">
  <div class="icon"></div>
  <span id="statusText">Initializing...</span>
</div>

<canvas id="waveform"></canvas>
<div id="chat"></div>

<input type="text" id="userInput" placeholder="Type a message..." />
<button id="sendBtn">Send</button>

<script>
const chat = document.getElementById('chat');
const userInput = document.getElementById('userInput');
const sendBtn = document.getElementById('sendBtn');
const status = document.getElementById('status');
const statusText = document.getElementById('statusText');
const waveform = document.getElementById('waveform');

const messageQueue = [];
let processingQueue = false;

// Setup canvas for waveform
const canvasCtx = waveform.getContext('2d');
let audioContext, analyser, dataArray, source;

// Initialize waveform visualization
async function initWaveform() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    audioContext = new AudioContext();
    analyser = audioContext.createAnalyser();
    source = audioContext.createMediaStreamSource(stream);
    source.connect(analyser);
    analyser.fftSize = 256;
    const bufferLength = analyser.frequencyBinCount;
    dataArray = new Uint8Array(bufferLength);

    drawWaveform();
  } catch(e) {
    console.error('Waveform init error', e);
  }
}

function drawWaveform() {
  requestAnimationFrame(drawWaveform);
  if (!analyser) return;

  analyser.getByteTimeDomainData(dataArray);
  canvasCtx.fillStyle = '#222';
  canvasCtx.fillRect(0, 0, waveform.width, waveform.height);

  canvasCtx.lineWidth = 2;
  canvasCtx.strokeStyle = '#1a73e8';
  canvasCtx.beginPath();

  const sliceWidth = waveform.width * 1.0 / dataArray.length;
  let x = 0;

  for(let i = 0; i < dataArray.length; i++) {
    const v = dataArray[i] / 128.0;
    const y = v * waveform.height/2;
    if(i === 0) {
      canvasCtx.moveTo(x, y);
    } else {
      canvasCtx.lineTo(x, y);
    }
    x += sliceWidth;
  }
  canvasCtx.lineTo(waveform.width, waveform.height/2);
  canvasCtx.stroke();
}

// Chat functions
function addMessage(text, sender) {
  const div = document.createElement('div');
  div.className = `message ${sender}`;
  div.textContent = text;
  chat.appendChild(div);
  chat.scrollTop = chat.scrollHeight;
}

async function getAIResponse(message) {
  // Replace with real API call
  return `You said: "${message}"`;
}

async function processQueue() {
  if (processingQueue || messageQueue.length === 0) return;
  processingQueue = true;

  while(messageQueue.length > 0) {
    const message = messageQueue.shift();
    addMessage(message, 'user');
    const response = await getAIResponse(message);
    addMessage(response, 'ai');

    status.className = 'speaking';
    statusText.textContent = '💬 Speaking...';
    await speak(response);

    status.className = 'listening';
    statusText.textContent = '🎤 Listening...';
  }

  processingQueue = false;
}

function enqueueMessage(message) {
  messageQueue.push(message);
  processQueue();
}

function speak(text) {
  return new Promise(resolve => {
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.onend = resolve;
    speechSynthesis.speak(utterance);
  });
}

// Input handlers
sendBtn.addEventListener('click', () => {
  const message = userInput.value.trim();
  if(!message) return;
  userInput.value = '';
  enqueueMessage(message);
});

userInput.addEventListener('keypress', e => {
  if(e.key === 'Enter') {
    const message = userInput.value.trim();
    if(!message) return;
    userInput.value = '';
    enqueueMessage(message);
  }
});

// Speech recognition
if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
  alert('Speech Recognition not supported');
  statusText.textContent = '⚠️ Not supported';
} else {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  const recognition = new SpeechRecognition();
  recognition.lang = 'en-US';
  recognition.interimResults = true;
  recognition.maxAlternatives = 1;
  recognition.continuous = true;

  status.className = 'listening';
  statusText.textContent = '🎤 Listening...';

  recognition.onresult = (event) => {
    let transcript = '';
    for(let i=event.resultIndex; i<event.results.length; i++) {
      transcript += event.results[i][0].transcript;
    }
    if(event.results[event.results.length-1].isFinal) {
      enqueueMessage(transcript);
    }
  };

  recognition.onerror = (event) => {
    console.error('Speech recognition error', event.error);
    statusText.textContent = '⚠️ Error';
  };

  recognition.onend = () => recognition.start();
  recognition.start();
}

// Start waveform
initWaveform();

// Resize canvas to fit container
function resizeCanvas() {
  waveform.width = waveform.clientWidth;
  waveform.height = waveform.clientHeight;
}
window.addEventListener('resize', resizeCanvas);
resizeCanvas();
</script>
</body>
</html>
<select id="voiceStyle">
  <option value="default">Default</option>
  <option value="energetic">Energetic</option>
  <option value="calm">Calm</option>
  <option value="deep">Deep</option>
  <option value="robot">Robot</option>
</select>
function speak(text) {
  return new Promise(resolve => {
    const utterance = new SpeechSynthesisUtterance(text);
    const style = document.getElementById('voiceStyle').value;

    switch(style) {
      case 'energetic':
        utterance.pitch = 1.8;
        utterance.rate = 1.4;
        break;
      case 'calm':
        utterance.pitch = 0.7;
        utterance.rate = 0.8;
        break;
      case 'deep':
        utterance.pitch = 0.5;
        utterance.rate = 1.0;
        break;
      case 'robot':
        utterance.pitch = 1.0;
        utterance.rate = 0.6;
        break;
      default:
        utterance.pitch = 1.0;
        utterance.rate = 1.0;
    }

    // Optional: choose a different voice if available
    const voices = speechSynthesis.getVoices();
    if(voices.length > 0) utterance.voice = voices[0];

    utterance.onend = resolve;
    speechSynthesis.speak(utterance);
  });
}
from flask import Flask, request, jsonify
from trading_system import execute_trade, get_portfolio_status  # your trading logic

app = Flask(__name__)

@app.route('/api/trade', methods=['POST'])
def trade():
    data = request.json
    command = data.get('command', '')

    try:
        if 'buy' in command.lower() or 'sell' in command.lower():
            result = execute_trade(command)  # returns confirmation string
        elif 'portfolio' in command.lower():
            result = get_portfolio_status()  # returns portfolio summary
        else:
            result = f"Unrecognized command: {command}"
        return jsonify({'response': result})
    except Exception as e:
        return jsonify({'response': f'Error: {str(e)}'}), 400

if __name__ == '__main__':
    app.run(debug=True)
async function getAIResponse(message) {
  try {
    const response = await fetch('/api/trade', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ command: message })
    });
    const data = await response.json();
    return data.response;
  } catch (err) {
    console.error(err);
    return "Error communicating with trading system.";
  }from flask import Flask, request, jsonify
from ai_website_tool import process_command  # your AI code for reformation

app = Flask(__name__)

@app.route('/api/refactor', methods=['POST'])
def refactor():
    data = request.json
    command = data.get('command', '')
    try:
        result = process_command(command)  # returns reformatted HTML/CSS/JS or instructions
        return jsonify({'response': result})
    except Exception as e:
        return jsonify({'response': f'Error: {str(e)}'}), 400

if __name__ == '__main__':
    app.run(debug=True)

}
async function getAIResponse(message) {
  try {
    const response = await fetch('/api/refactor', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ command: message })
    });
    const data = await response.json();
    return data.response;
  } catch (err) {
    console.error(err);
    return "Error communicating with AI tool.";
  }
}
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AI Website Refactor Assistant</title>
<style>
  body {
    font-family: Arial, sans-serif;
    max-width: 700px;
    margin: 50px auto;
    background: #f0f2f5;
    text-align: center;
  }

  #chat {
    border: 1px solid #ccc;
    padding: 15px;
    height: 350px;
    overflow-y: auto;
    margin-bottom: 15px;
    background: #fff;
    border-radius: 10px;
  }

  .message { margin: 10px 0; }
  .user { color: #1a73e8; }
  .ai { color: #0f9d58; }

  #status {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 15px;
    font-size: 1.2em;
    margin-bottom: 10px;
  }

  .icon { width: 24px; height: 24px; border-radius: 50%; }

  .listening .icon { background-color: orange; animation: pulse 1s infinite; }
  .speaking .icon { background-color: green; animation: pulse 0.6s infinite; }

  @keyframes pulse {
    0% { transform: scale(1); opacity: 0.7; }
    50% { transform: scale(1.5); opacity: 1; }
    100% { transform: scale(1); opacity: 0.7; }
  }

  #waveform { width: 100%; height: 50px; background: #222; border-radius: 5px; margin-bottom: 15px; }

  select, input, button { padding: 10px; font-size: 1em; margin: 5px; border-radius: 5px; }
  button { cursor: pointer; }
</style>
</head>
<body>

<h1>AI Website Refactor Assistant</h1>

<div id="status">
  <div class="icon"></div>
  <span id="statusText">Initializing...</span>
</div>

<canvas id="waveform"></canvas>

<select id="voiceStyle">
  <option value="default">Default</option>
  <option value="energetic">Energetic</option>
  <option value="calm">Calm</option>
  <option value="deep">Deep</option>
  <option value="robot">Robot</option>
</select>

<div id="chat"></div>

<input type="text" id="userInput" placeholder="Type a command..." />
<button id="sendBtn">Send</button>

<script>
const chat = document.getElementById('chat');
const userInput = document.getElementById('userInput');
const sendBtn = document.getElementById('sendBtn');
const status = document.getElementById('status');
const statusText = document.getElementById('statusText');
const waveform = document.getElementById('waveform');

const messageQueue = [];
let processingQueue = false;

// Setup canvas for waveform
const canvasCtx = waveform.getContext('2d');
let audioContext, analyser, dataArray, source;

async function initWaveform() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    audioContext = new AudioContext();
    analyser = audioContext.createAnalyser();
    source = audioContext.createMediaStreamSource(stream);
    source.connect(analyser);
    analyser.fftSize = 256;
    dataArray = new Uint8Array(analyser.frequencyBinCount);
    drawWaveform();
  } catch(e) { console.error('Waveform init error', e); }
}

function drawWaveform() {
  requestAnimationFrame(drawWaveform);
  if (!analyser) return;
  analyser.getByteTimeDomainData(dataArray);

  canvasCtx.fillStyle = '#222';
  canvasCtx.fillRect(0, 0, waveform.width, waveform.height);

  canvasCtx.lineWidth = 2;
  canvasCtx.strokeStyle = '#1a73e8';
  canvasCtx.beginPath();

  const sliceWidth = waveform.width / dataArray.length;
  let x = 0;
  for (let i = 0; i < dataArray.length; i++) {
    const v = dataArray[i] / 128.0;
    const y = v * waveform.height/2;
    if (i === 0) canvasCtx.moveTo(x, y);
    else canvasCtx.lineTo(x, y);
    x += sliceWidth;
  }
  canvasCtx.lineTo(waveform.width, waveform.height/2);
  canvasCtx.stroke();
}

// Chat functions
function addMessage(text, sender) {
  const div = document.createElement('div');
  div.className = `message ${sender}`;
  div.textContent = text;
  chat.appendChild(div);
  chat.scrollTop = chat.scrollHeight;
}

async function getAIResponse(message) {
  try {
    const response = await fetch('/api/refactor', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ command: message })
    });
    const data = await response.json();
    return data.response;
  } catch(err) {
    console.error(err);
    return "Error communicating with AI tool.";
  }
}

async function processQueue() {
  if (processingQueue || messageQueue.length === 0) return;
  processingQueue = true;

  while(messageQueue.length > 0) {
    const message = messageQueue.shift();
    addMessage(message, 'user');
    const response = await getAIResponse(message);
    addMessage(response, 'ai');

    status.className = 'speaking';
    statusText.textContent = '💬 Speaking...';
    await speak(response);

    status.className = 'listening';
    statusText.textContent = '🎤 Listening...';
  }

  processingQueue = false;
}

function enqueueMessage(message) {
  messageQueue.push(message);
  processQueue();
}

function speak(text) {
  return new Promise(resolve => {
    const utterance = new SpeechSynthesisUtterance(text);
    const style = document.getElementById('voiceStyle').value;

    switch(style) {
      case 'energetic': utterance.pitch=1.8; utterance.rate=1.4; break;
      case 'calm': utterance.pitch=0.7; utterance.rate=0.8; break;
      case 'deep': utterance.pitch=0.5; utterance.rate=1.0; break;
      case 'robot': utterance.pitch=1.0; utterance.rate=0.6; break;
      default: utterance.pitch=1.0; utterance.rate=1.0;
    }

    const voices = speechSynthesis.getVoices();
    if (voices.length > 0) utterance.voice = voices[0];

    utterance.onend = resolve;
    speechSynthesis.speak(utterance);
  });
}

// Input handlers
sendBtn.addEventListener('click', () => {
  const message = userInput.value.trim();
  if(!message) return;
  userInput.value = '';
  enqueueMessage(message);
});

userInput.addEventListener('keypress', e => {
  if(e.key === 'Enter') {
    const message = userInput.value.trim();
    if(!message) return;
    userInput.value = '';
    enqueueMessage(message);
  }
});

// Speech recognition
if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
  alert('Speech Recognition not supported');
  statusText.textContent = '⚠️ Not supported';
} else {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  const recognition = new SpeechRecognition();
  recognition.lang = 'en-US';
  recognition.interimResults = true;
  recognition.maxAlternatives = 1;
  recognition.continuous = true;

  status.className = 'listening';
  statusText.textContent = '🎤 Listening...';

  recognition.onresult = (event) => {
    let transcript = '';
    for(let i=event.resultIndex;i<event.results.length;i++) {
      transcript += event.results[i][0].transcript;
    }
    if(event.results[event.results.length-1].isFinal) {
      enqueueMessage(transcript);
    }
  };

  recognition.onerror = (event) => {
    console.error('Speech recognition error', event.error);
    statusText.textContent = '⚠️ Error';
  };

  recognition.onend = () => recognition.start();
  recognition.start();
}

// Initialize waveform
initWaveform();
function resizeCanvas() {
  waveform.width = waveform.clientWidth;
  waveform.height = waveform.clientHeight;
}
window.addEventListener('resize', resizeCanvas);
resizeCanvas();
</script>
</body>
</html>
from flask import Flask, request, jsonify
from flask_cors import CORS
# import your AI logic here
# e.g., from ai_website_tool import process_command

app = Flask(__name__)
CORS(app)  # allow cross-origin requests if frontend served separately

@app.route('/api/refactor', methods=['POST'])
def refactor():
    data = request.json
    command = data.get('command', '').strip()
    
    if not command:
        return jsonify({'response': "No command received."})

    try:
        # Replace this with your actual AI website processing logic
        # Example: process_command(command) -> returns HTML/CSS/JS suggestions
        result = fake_ai_process(command)
        return jsonify({'response': result})
    except Exception as e:
        return jsonify({'response': f"Error: {str(e)}"}), 500


# ------------------------
# Example placeholder AI logic
# Replace this with real AI integration (OpenAI, LLM, etc.)
def fake_ai_process(command):
    """
    Simulates AI processing for website refactoring.
    In real tool, integrate your AI model here.
    """
    if "responsive" in command.lower():
        return "✅ Your website layout has been optimized for mobile devices."
    elif "dark mode" in command.lower():
        return "🌙 Dark mode CSS snippet generated. Add it to your stylesheet."
    elif "optimize" in command.lower():
        return "⚡ CSS and JS files minified for faster loading."
    elif "reformat" in command.lower():
        return "🖌️ HTML structure reorganized for cleaner code."
    else:
        return f"🤖 AI analyzed your command: '{command}' and suggests general improvements."

# ------------------------

if __name__ == '__main__':
    app.run(debug=True)
{
  "response": "✅ Your website layout has been optimized for mobile devices."
}
from flask import Flask, request, jsonify
from flask_cors import CORS
# import your AI engine here
# e.g., from ai_website_tool import process_command

app = Flask(__name__)
CORS(app)

@app.route('/api/refactor', methods=['POST'])
def refactor():
    data = request.json
    command = data.get('command', '').strip()
    
    if not command:
        return jsonify({'response': "No command received."})

    try:
        # Replace with real AI engine call
        result = fake_ai_process(command)
        return jsonify({'response': result})
    except Exception as e:
        return jsonify({'response': f"Error: {str(e)}"}), 500

def fake_ai_process(command):
    """
    Placeholder AI processing logic.
    Replace with actual AI code for website refactor.
    """
    if "responsive" in command.lower():
        return "✅ Your website layout has been optimized for mobile devices."
    elif "dark mode" in command.lower():
        return "🌙 Dark mode CSS snippet generated. Add it to your stylesheet."
    elif "optimize" in command.lower():
        return "⚡ CSS and JS files minified for faster loading."
    elif "reformat" in command.lower():
        return "🖌️ HTML structure reorganized for cleaner code."
    else:
        return f"🤖 AI analyzed your command: '{command}' and suggests general improvements."

if __name__ == '__main__':
    app.run(debug=True)
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AI Website Refactor Assistant</title>
<style>
  body { font-family: Arial, sans-serif; max-width: 700px; margin: 50px auto; background: #f0f2f5; text-align: center; }
  #chat { border: 1px solid #ccc; padding: 15px; height: 350px; overflow-y: auto; margin-bottom: 15px; background: #fff; border-radius: 10px; }
  .message { margin: 10px 0; }
  .user { color: #1a73e8; }
  .ai { color: #0f9d58; }
  #status { display: flex; justify-content: center; align-items: center; gap: 15px; font-size: 1.2em; margin-bottom: 10px; }
  .icon { width: 24px; height: 24px; border-radius: 50%; }
  .listening .icon { background-color: orange; animation: pulse 1s infinite; }
  .speaking .icon { background-color: green; animation: pulse 0.6s infinite; }
  @keyframes pulse { 0% { transform: scale(1); opacity: 0.7; } 50% { transform: scale(1.5); opacity: 1; } 100% { transform: scale(1); opacity: 0.7; } }
  #waveform { width: 100%; height: 50px; background: #222; border-radius: 5px; margin-bottom: 15px; }
  select, input, button { padding: 10px; font-size: 1em; margin: 5px; border-radius: 5px; }
  button { cursor: pointer; }
</style>
</head>
<body>

<h1>AI Website Refactor Assistant</h1>

<div id="status">
  <div class="icon"></div>
  <span id="statusText">Initializing...</span>
</div>

<canvas id="waveform"></canvas>

<select id="voiceStyle">
  <option value="default">Default</option>
  <option value="energetic">Energetic</option>
  <option value="calm">Calm</option>
  <option value="deep">Deep</option>
  <option value="robot">Robot</option>
</select>

<div id="chat"></div>

<input type="text" id="userInput" placeholder="Type a command..." />
<button id="sendBtn">Send</button>

<script>
const chat = document.getElementById('chat');
const userInput = document.getElementById('userInput');
const sendBtn = document.getElementById('sendBtn');
const status = document.getElementById('status');
const statusText = document.getElementById('statusText');
const waveform = document.getElementById('waveform');

const messageQueue = [];
let processingQueue = false;

// Setup waveform
const canvasCtx = waveform.getContext('2d');
let audioContext, analyser, dataArray, source;

async function initWaveform() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    audioContext = new AudioContext();
    analyser = audioContext.createAnalyser();
    source = audioContext.createMediaStreamSource(stream);
    source.connect(analyser);
    analyser.fftSize = 256;
    dataArray = new Uint8Array(analyser.frequencyBinCount);
    drawWaveform();
  } catch(e) { console.error(e); }
}

function drawWaveform() {
  requestAnimationFrame(drawWaveform);
  if (!analyser) return;
  analyser.getByteTimeDomainData(dataArray);

  canvasCtx.fillStyle = '#222';
  canvasCtx.fillRect(0, 0, waveform.width, waveform.height);

  canvasCtx.lineWidth = 2;
  canvasCtx.strokeStyle = '#1a73e8';
  canvasCtx.beginPath();

  const sliceWidth = waveform.width / dataArray.length;
  let x = 0;
  for (let i = 0; i < dataArray.length; i++) {
    const v = dataArray[i] / 128.0;
    const y = v * waveform.height/2;
    if (i === 0) canvasCtx.moveTo(x, y);
    else canvasCtx.lineTo(x, y);
    x += sliceWidth;
  }
  canvasCtx.lineTo(waveform.width, waveform.height/2);
  canvasCtx.stroke();
}

// Chat functions
function addMessage(text, sender) {
  const div = document.createElement('div');
  div.className = `message ${sender}`;
  div.textContent = text;
  chat.appendChild(div);
  chat.scrollTop = chat.scrollHeight;
}

async function getAIResponse(message) {
  try {
    const response = await fetch('/api/refactor', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ command: message })
    });
    const data = await response.json();
    return data.response;
  } catch(err) {
    console.error(err);
    return "Error communicating with AI tool.";
  }
}

async function processQueue() {
  if (processingQueue || messageQueue.length === 0) return;
  processingQueue = true;

  while(messageQueue.length > 0) {
    const message = messageQueue.shift();
    addMessage(message, 'user');
    const response = await getAIResponse(message);
    addMessage(response, 'ai');

    status.className = 'speaking';
    statusText.textContent = '💬 Speaking...';
    await speak(response);

    status.className = 'listening';
    statusText.textContent = '🎤 Listening...';
  }

  processingQueue = false;
}

function enqueueMessage(message) {
  messageQueue.push(message);
  processQueue();
}

function speak(text) {
  return new Promise(resolve => {
    const utterance = new SpeechSynthesisUtterance(text);
    const style = document.getElementById('voiceStyle').value;

    switch(style) {
      case 'energetic': utterance.pitch=1.8; utterance.rate=1.4; break;
      case 'calm': utterance.pitch=0.7; utterance.rate=0.8; break;
      case 'deep': utterance.pitch=0.5; utterance.rate=1.0; break;
      case 'robot': utterance.pitch=1.0; utterance.rate=0.6; break;
      default: utterance.pitch=1.0; utterance.rate=1.0;
    }

    const voices = speechSynthesis.getVoices();
    if (voices.length > 0) utterance.voice = voices[0];

    utterance.onend = resolve;
    speechSynthesis.speak(utterance);
  });
}

// Input handlers
sendBtn.addEventListener('click', () => {
  const message = userInput.value.trim();
  if(!message) return;
  userInput.value = '';
  enqueueMessage(message);
});

userInput.addEventListener('keypress', e => {
  if(e.key==='Enter') {
    const message = userInput.value.trim();
    if(!message) return;
    userInput.value = '';
    enqueueMessage(message);
  }
});

// Speech recognition
if (!('webkitSpeechRecognition' in window) && !('SpeechRecognition' in window)) {
  alert('Speech Recognition not supported');
  statusText.textContent = '⚠️ Not supported';
} else {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  const recognition = new SpeechRecognition();
  recognition.lang = 'en-US';
  recognition.interimResults = true;
  recognition.maxAlternatives = 1;
  recognition.continuous = true;

  status.className = 'listening';
  statusText.textContent = '🎤 Listening...';

  recognition.onresult = (event) => {
    let transcript = '';
    for(let i=event.resultIndex;i<event.results.length;i++) {
      transcript += event.results[i][0].transcript;
    }
    if(event.results[event.results.length-1].isFinal) {
      enqueueMessage(transcript);
    }
  };

  recognition.onerror = (event
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AI Website Refactor Assistant</title>
<style>
body {
  font-family: Arial, sans-serif;
  max-width: 900px;
  margin: 30px auto;
  background: #f0f2f5;
  text-align: center;
}

h1 { margin-bottom: 10px; }
#guide { background: #fff3cd; padding: 15px; border-radius: 8px; margin-bottom: 15px; text-align: left; }

#chat {
  border: 1px solid #ccc;
  padding: 15px;
  height: 250px;
  overflow-y: auto;
  margin-bottom: 15px;
  background: #fff;
  border-radius: 10px;
}

.message { margin: 10px 0; }
.user { color: #1a73e8; }
.ai { color: #0f9d58; }

#status {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 15px;
  font-size: 1.2em;
  margin-bottom: 10px;
}

.icon { width: 24px; height: 24px; border-radius: 50%; }
.listening .icon { background-color: orange; animation: pulse 1s infinite; }
.speaking .icon { background-color: green; animation: pulse 0.6s infinite; }

@keyframes pulse {
  0% { transform: scale(1); opacity: 0.7; }
  50% { transform: scale(1.5); opacity: 1; }
  100% { transform: scale(1); opacity: 0.7; }
}

#waveform { width: 100%; height: 50px; background: #222; border-radius: 5px; margin-bottom: 10px; }

#controls { display: flex; justify-content: center; gap: 10px; margin-bottom: 15px; }
select, input, button { padding: 10px; font-size: 1em; border-radius: 5px; }
button { cursor: pointer; }

#editor-container { display: flex; gap: 10px; margin-top: 15px; }
textarea, iframe {
  flex: 1;
  height: 300px;
  border-radius: 8px;
  border: 1px solid #ccc;
  font-family: monospace;
  font-size: 14px;
  padding: 10px;
}
iframe { background: #fff; }
</style>
</head>
<body>

<h1>AI Website Refactor Assistant</h1>

<div id="guide">
<strong>How to Use & Speed Study of Programming:</strong>
<ul>
<li>Type or speak commands like "Make homepage responsive" or "Add dark mode".</li>
<li>Observe AI suggestions in chat and listen via voice output.</li>
<li>Edit the code in the left editor; live preview appears on the right.</li>
<li><strong>Speed Study Tip:</strong> Focus on small improvements, repeat AI suggestions, and practice refactoring repeatedly to increase coding speed and understanding.</li>
</ul>
</div>

<div id="status">
  <div class="icon"></div>
  <span id="statusText">Initializing...</span>
</div>

<canvas id="waveform"></canvas>

<div id="controls">
<select id="voiceStyle">
  <option value="default">Default</option>
  <option value="energetic">Energetic</option>
  <option value="calm">Calm</option>
  <option value="deep">Deep</option>
  <option value="robot">Robot</option>
</select>

<input type="text" id="userInput" placeholder="Type a command..." />
<button id="sendBtn">Send</button>
</div>

<div id="chat"></div>

<div id="editor-container">
<textarea id="codeEditor" placeholder="AI-refactored HTML/CSS/JS will appear here..."></textarea>
<iframe id="livePreview"></iframe>
</div>

<script>
const chat = document.getElementById('chat');
const userInput = document.getElementById('userInput');
const sendBtn = document.getElementById('sendBtn');
const status = document.getElementById('status');
const statusText = document.getElementById('statusText');
const waveform = document.getElementById('waveform');
const codeEditor = document.getElementById('codeEditor');
const livePreview = document.getElementById('livePreview');

const messageQueue = [];
let processingQueue = false;

// Waveform setup
const canvasCtx = waveform.getContext('2d');
let audioContext, analyser, dataArray, source;

async function initWaveform() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    audioContext = new AudioContext();
    analyser = audioContext.createAnalyser();
    source = audioContext.createMediaStreamSource(stream);
    source.connect(analyser);
    analyser.fftSize = 256;
    dataArray = new Uint8Array(analyser.frequencyBinCount);
    drawWaveform();
  } catch(e) { console.error(e); }
}

function drawWaveform() {
  requestAnimationFrame(drawWaveform);
  if (!analyser) return;
  analyser.getByteTimeDomainData(dataArray);

  canvasCtx.fillStyle = '#222';
  canvasCtx.fillRect(0,0,waveform.width,waveform.height);

  canvasCtx.lineWidth = 2;
  canvasCtx.strokeStyle = '#1a73e8';
  canvasCtx.beginPath();
  let sliceWidth = waveform.width / dataArray.length;
  let x = 0;
  for(let i=0;i<dataArray.length;i++){
    const v = dataArray[i]/128.0;
    const y = v*waveform.height/2;
    if(i===0) canvasCtx.moveTo(x,y);
    else canvasCtx.lineTo(x,y);
    x += sliceWidth;
  }
  canvasCtx.lineTo(waveform.width,waveform.height/2);
  canvasCtx.stroke();
}

// Chat and queue functions
function addMessage(text,sender){
  const div=document.createElement('div');
  div.className=`message ${sender}`;
  div.textContent=text;
  chat.appendChild(div);
  chat.scrollTop=chat.scrollHeight;
}

async function getAIResponse(message){
  try {
    const response = await fetch('/api/refactor',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({command:message})
    });
    const data=await response.json();
    // Insert into code editor for live preview
    codeEditor.value=data.response;
    updatePreview();
    return data.response;
  }catch(err){
    console.error(err);
    return "Error communicating with AI tool.";
  }
}

async function processQueue(){
  if(processingQueue || messageQueue.length===0) return;
  processingQueue=true;
  while(messageQueue.length>0){
    const message=messageQueue.shift();
    addMessage(message,'user');
    const response=await getAIResponse(message);
    addMessage(response,'ai');
    status.className='speaking';
    statusText.textContent='💬 Speaking...';
    await speak(response);
    status.className='listening';
    statusText.textContent='🎤 Listening...';
  }
  processingQueue=false;
}

function enqueueMessage(message){
  messageQueue.push(message);
  processQueue();
}

// Speech synthesis
function speak(text){
  return new Promise(resolve=>{
    const utterance=new SpeechSynthesisUtterance(text);
    const style=document.getElementById('voiceStyle').value;
    switch(style){
      case 'energetic': utterance.pitch=1.8; utterance.rate=1.4; break;
      case 'calm': utterance.pitch=0.7; utterance.rate=0.8; break;
      case 'deep': utterance.pitch=0.5; utterance.rate=1.0; break;
      case 'robot': utterance.pitch=1.0; utterance.rate=0.6; break;
      default: utterance.pitch=1.0; utterance.rate=1.0;
    }
    const voices=speechSynthesis.getVoices();
    if(voices.length>0) utterance.voice=voices[0];
    utterance.onend=resolve;
    speechSynthesis.speak(utterance);
  });
}

// Input handlers
sendBtn.addEventListener('click',()=>{const msg=userInput.value.trim();if(!msg)return;userInput.value='';enqueueMessage(msg);});
userInput.addEventListener('keypress',e=>{if(e.key==='Enter'){const msg=userInput.value.trim();if(!msg)return;userInput.value='';enqueueMessage(msg);}});

// Speech recognition
if(!('webkitSpeechRecognition' in window)&&!('SpeechRecognition' in window)){
  alert('Speech Recognition not supported');
  statusText.textContent='⚠️ Not supported';
}else{
  const SpeechRecognition=window.SpeechRecognition||window.webkitSpeechRecognition;
  const recognition=new SpeechRecognition();
  recognition.lang='en-US';
  recognition.interimResults=true;
  recognition.maxAlternatives=1;
  recognition.continuous=true;
  status.className='listening';
  statusText.textContent='🎤 Listening...';
  recognition.onresult=(event)=>{
    let transcript='';
    for(let i=event.resultIndex;i<event.results.length;i++){transcript+=event.results[i][0].transcript;}
    if(event.results[event.results.length-1].isFinal){enqueueMessage(transcript);}
  };
  recognition.onerror=(event)=>{console.error(event.error); statusText.textContent='⚠️ Error';};
  recognition.onend=()=>recognition.start();
  recognition.start();
}

// Code editor -> live preview
function updatePreview(){
  const previewDoc=livePreview.contentDocument||livePreview.contentWindow.document;
  previewDoc.open();
  previewDoc.write(codeEditor.value);
  previewDoc.close();
}

codeEditor.addEventListener('input',updatePreview);

// Waveform init and resize
initWaveform();
function resizeCanvas(){waveform.width=waveform.clientWidth; waveform.height=waveform.clientHeight;}
window.addEventListener('resize',resizeCanvas);
resizeCanvas();
</script>

</body>
</html>
def fake_ai_process(command):
    """
    Simulates AI processing with teaching.
    Returns code with inline comments explaining the changes.
    """
    if "responsive" in command.lower():
        code = """<!-- Responsive layout improvements -->
<style>
  body { max-width: 100%; padding: 10px; }
  @media (max-width: 600px) {
    nav { display: block; }
  }
</style>
<!-- Tip: Use media queries to adapt layout for mobile screens -->"""
        explanation = "✅ Added media queries and flexible width for responsiveness."
        return code + "\n\n" + explanation
    elif "dark mode" in command.lower():
        code = """<!-- Dark mode CSS -->
<style>
  body { background-color: #121212; color: #eee; }
</style>
<!-- Tip: Use high-contrast colors for readability in dark mode -->"""
        explanation = "🌙 Generated dark mode CSS with comments."
        return code + "\n\n" + explanation
    elif "optimize" in command.lower():
        code = """<!-- Minified CSS/JS -->
<!-- Tip: Minifying reduces file size and improves load speed -->"""
        explanation = "⚡ Suggested minification for faster website performance."
        return code + "\n\n" + explanation
    else:
        code = "<!-- General improvements suggested by AI -->"
        explanation = f"🤖 Analyzed command '{command}' and added teaching comments."
        return code + "\n\n" + explanation
async function getAIResponse(message){
  try {
    const response = await fetch('/api/refactor',{
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({command:message})
    });
    const data=await response.json();
    
    // Insert into code editor for live preview
    codeEditor.value = data.response;

    // Optionally highlight teaching comments with color
    const lines = data.response.split("\n");
    const highlighted = lines.map(line => {
      if(line.trim().startsWith("<!--")) return `/* ${line.replace("<!--","").replace("-->","").trim()} */`;
      return line;
    }).join("\n");
    codeEditor.value = highlighted;

    updatePreview();
    return data.response;
  }catch(err){
    console.error(err);
    return "Error communicating with AI tool.";
  }
}
from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import os

app = Flask(__name__)
CORS(app)

MEMORY_FILE = "user_history.json"

# Load or initialize memory
if os.path.exists(MEMORY_FILE):
    with open(MEMORY_FILE, "r") as f:
        user_memory = json.load(f)
else:
    user_memory = {"commands": [], "responses": []}

@app.route('/api/refactor', methods=['POST'])
def refactor():
    data = request.json
    command = data.get('command', '').strip()
    
    if not command:
        return jsonify({'response': "No command received."})

    try:
        # AI processes command with teaching
        result = adaptive_ai_process(command)

        # Save to memory
        user_memory["commands"].append(command)
        user_memory["responses"].append(result)
        with open(MEMORY_FILE, "w") as f:
            json.dump(user_memory, f, indent=2)

        return jsonify({'response': result})
    except Exception as e:
        return jsonify({'response': f"Error: {str(e)}"}), 500


def adaptive_ai_process(command):
    """
    Example AI that adapts based on user history.
    Replace with actual LLM or AI model.
    """
    history_count = sum(1 for c in user_memory["commands"] if command.lower() in c.lower())

    explanation_note = ""
    if history_count > 0:
        explanation_note = "\n<!-- Note: You've asked similar commands before, AI adapts to your style -->"

    if "responsive" in command.lower():
        code = """<!-- Responsive layout improvements -->
<style>
  body { max-width: 100%; padding: 10px; }
  @media (max-width: 600px) { nav { display: block; } }
</style>
<!-- Tip: Use media queries to adapt layout for mobile screens -->"""
        return code + explanation_note + "\n✅ Added media queries and flexible width for responsiveness."

    elif "dark mode" in command.lower():
        code = """<!-- Dark mode CSS -->
<style>
  body { background-color: #121212; color: #eee; }
</style>
<!-- Tip: Use high-contrast colors for readability in dark mode -->"""
        return code + explanation_note + "\n🌙 Generated dark mode CSS with comments."

    else:
        code = "<!-- General improvements suggested by AI -->"
        return code + explanation_note + f"\n🤖 AI analyzed command '{command}' and adds teaching comments."
    

if __name__ == '__main__':
    app.run(debug=True)
function highlightAdaptiveNotes(response){
  // Highlight any teaching notes in comments
  const lines = response.split("\n").map(line=>{
    if(line.includes("Note:")) return `%c${line}`;
    return line;
  }).join("\n");
  return lines;
}
from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import os

app = Flask(__name__)
CORS(app)

MEMORY_FILE = "user_history.json"

# Load or initialize memory
if os.path.exists(MEMORY_FILE):
    with open(MEMORY_FILE, "r") as f:
        user_memory = json.load(f)
else:
    user_memory = {"commands": [], "responses": []}

@app.route('/api/refactor', methods=['POST'])
def refactor():
    data = request.json
    command = data.get('command', '').strip()
    
    if not command:
        return jsonify({'response': "No command received."})

    try:
        result = adaptive_ai_process(command)

        # Save to memory
        user_memory["commands"].append(command)
        user_memory["responses"].append(result)
        with open(MEMORY_FILE, "w") as f:
            json.dump(user_memory, f, indent=2)

        return jsonify({'response': result})
    except Exception as e:
        return jsonify({'response': f"Error: {str(e)}"}), 500


def adaptive_ai_process(command):
    """
    AI that refactors, teaches, and adapts based on user history.
    """
    history_count = sum(1 for c in user_memory["commands"] if command.lower() in c.lower())
    explanation_note = ""
    if history_count > 0:
        explanation_note = "\n<!-- Note: You've asked similar commands before; AI adapts to your style -->"

    if "responsive" in command.lower():
        code = """<!-- Responsive layout improvements -->
<style>
  body { max-width: 100%; padding: 10px; }
  @media (max-width: 600px) { nav { display: block; } }
</style>
<!-- Tip: Use media queries to adapt layout for mobile screens -->"""
        return code + explanation_note + "\n✅ Added media queries for responsiveness."

    elif "dark mode" in command.lower():
        code = """<!-- Dark mode CSS -->
<style>
  body { background-color: #121212; color: #eee; }
</style>
<!-- Tip: Use high-contrast colors for readability in dark mode -->"""
        return code + explanation_note + "\n🌙 Generated dark mode CSS with teaching comments."

    elif "optimize" in command.lower():
        code = """<!-- Optimized CSS/JS -->
<!-- Tip: Minify files for faster load time -->"""
        return code + explanation_note + "\n⚡ Suggested minification for performance."

    else:
        code = "<!-- General improvements suggested by AI -->"
        return code + explanation_note + f"\n🤖 Analyzed '{command}' and added teaching comments."

if __name__ == '__main__':
    app.run(debug=True)
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AI Website Refactor Assistant</title>
<style>
body { font-family: Arial; max-width: 900px; margin: 30px auto; background: #f0f2f5; text-align: center; }
h1 { margin-bottom: 10px; }
#guide { background: #fff3cd; padding: 15px; border-radius: 8px; margin-bottom: 15px; text-align: left; }
#chat { border:1px solid #ccc; padding:15px; height:250px; overflow-y:auto; margin-bottom:15px; background:#fff; border-radius:10px; }
.message { margin:10px 0; }
.user { color:#1a73e8; }
.ai { color:#0f9d58; }
#status { display:flex; justify-content:center; align-items:center; gap:15px; font-size:1.2em; margin-bottom:10px; }
.icon { width:24px; height:24px; border-radius:50%; }
.listening .icon { background-color: orange; animation: pulse 1s infinite; }
.speaking .icon { background-color: green; animation: pulse 0.6s infinite; }
@keyframes pulse { 0% { transform: scale(1); opacity:0.7; } 50% { transform: scale(1.5); opacity:1; } 100% { transform: scale(1); opacity:0.7; } }
#waveform { width:100%; height:50px; background:#222; border-radius:5px; margin-bottom:10px; }
#controls { display:flex; justify-content:center; gap:10px; margin-bottom:15px; }
select,input,button { padding:10px; font-size:1em; border-radius:5px; }
button { cursor:pointer; }
#editor-container { display:flex; gap:10px; margin-top:15px; }
textarea, iframe { flex:1; height:300px; border-radius:8px; border:1px solid #ccc; font-family: monospace; font-size:14px; padding:10px; }
iframe { background:#fff; }
</style>
</head>
<body>

<h1>AI Website Refactor Assistant</h1>

<div id="guide">
<strong>How to Use & Speed Study of Programming:</strong>
<ul>
<li>Type or speak commands like "Make homepage responsive" or "Add dark mode".</li>
<li>Observe AI suggestions in chat and listen via voice output.</li>
<li>Edit code in the editor; live preview updates instantly.</li>
<li>Practice repeated refactoring to increase coding speed and understanding.</li>
<li>AI remembers your previous commands and adapts its suggestions over time.</li>
</ul>
</div>

<div id="status">
  <div class="icon"></div>
  <span id="statusText">Initializing...</span>
</div>

<canvas id="waveform"></canvas>

<div id="controls">
<select id="voiceStyle">
  <option value="default">Default</option>
  <option value="energetic">Energetic</option>
  <option value="calm">Calm</option>
  <option value="deep">Deep</option>
  <option value="robot">Robot</option>
</select>
<input type="text" id="userInput" placeholder="Type a command..." />
<button id="sendBtn">Send</button>
</div>

<div id="chat"></div>

<div id="editor-container">
<textarea id="codeEditor" placeholder="AI-refactored HTML/CSS/JS will appear here..."></textarea>
<iframe id="livePreview"></iframe>
</div>

<script>
const chat = document.getElementById('chat');
const userInput = document.getElementById('userInput');
const sendBtn = document.getElementById('sendBtn');
const status = document.getElementById('status');
const statusText = document.getElementById('statusText');
const waveform = document.getElementById('waveform');
const codeEditor = document.getElementById('codeEditor');
const livePreview = document.getElementById('livePreview');

const messageQueue = [];
let processingQueue = false;

// Waveform setup
const canvasCtx = waveform.getContext('2d');
let audioContext, analyser, dataArray, source;
async function initWaveform(){
  try{
    const stream = await navigator.mediaDevices.getUserMedia({audio:true});
    audioContext = new AudioContext();
    analyser = audioContext.createAnalyser();
    source = audioContext.createMediaStreamSource(stream);
    source.connect(analyser);
    analyser.fftSize = 256;
    dataArray = new Uint8Array(analyser.frequencyBinCount);
    drawWaveform();
  }catch(e){ console.error(e); }
}
function drawWaveform(){
  requestAnimationFrame(drawWaveform);
  if(!analyser) return;
  analyser.getByteTimeDomainData(dataArray);
  canvasCtx.fillStyle='#222';
  canvasCtx.fillRect(0,0,waveform.width,waveform.height);
  canvasCtx.lineWidth=2; canvasCtx.strokeStyle='#1a73e8'; canvasCtx.beginPath();
  const sliceWidth = waveform.width / dataArray.length;
  let x=0;
  for(let i=0;i<dataArray.length;i++){
    const v=dataArray[i]/128.0; const y=v*waveform.height/2;
    if(i===0) canvasCtx.moveTo(x,y); else canvasCtx.lineTo(x,y);
    x+=sliceWidth;
  }
  canvasCtx.lineTo(waveform.width,waveform.height/2);
  canvasCtx.stroke();
}

// Chat functions
function addMessage(text,sender){
  const div=document.createElement('div');
  div.className=`message ${sender}`;
  div.textContent=text;
  chat.appendChild(div);
  chat.scrollTop=chat.scrollHeight;
}

async function getAIResponse(message){
  try{
    const response = await fetch('/api/refactor',{
      method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({command:message})
    });
    const data = await response.json();
    codeEditor.value = data.response;
    updatePreview();
    return data.response;
  }catch(err){ console.error(err); return "Error communicating with AI tool."; }
}

async function processQueue(){
  if(processingQueue || messageQueue.length===0) return;
  processingQueue = true;
  while(messageQueue.length>0){
    const message = messageQueue.shift();
    addMessage(message,'user');
    const response = await getAIResponse(message);
    addMessage(response,'ai');
    status.className='speaking';
    statusText.textContent='💬 Speaking...';
    await speak(response);
    status.className='listening';
    statusText.textContent='🎤 Listening...';
  }
  processingQueue = false;
}
function enqueueMessage(message){
  messageQueue.push(message);
  processQueue();
}

function speak(text){
  return new Promise(resolve=>{
    const utterance = new SpeechSynthesisUtterance(text);
    const style = document.getElementById('voiceStyle').value;
    switch(style){
      case 'energetic': utterance.pitch=1.8; utterance.rate=1.4; break;
      case 'calm': utterance.pitch=0.7; utterance.rate=0.8; break;
      case 'deep': utterance.pitch=0.5; utterance.rate=1.0; break;
      case 'robot': utterance.pitch=1.0; utterance.rate=0.6; break;
      default: utterance.pitch=1.0; utterance.rate=1.0;
    }
    const voices = speechSynthesis.getVoices();
    if(voices.length>0) utterance.voice = voices[0];
    utterance.onend = resolve;
    speechSynthesis.speak(utterance);
  });
}

// Input handlers
sendBtn.addEventListener('click',()=>{const msg=userInput.value.trim();if(!msg)return; userInput.value=''; enqueueMessage(msg);});
userInput.addEventListener('keypress',e=>{if(e.key==='Enter'){const msg=userInput.value.trim();if(!msg)return; userInput.value=''; enqueueMessage(msg);}});

// Speech recognition
if(!('webkitSpeechRecognition' in window)&&!('SpeechRecognition' in window)){
  alert('Speech Recognition not supported');
  statusText.textContent='⚠️ Not supported';
}else{
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
 <!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AI Website Refactor Assistant</title>
<style>
body { font-family: Arial; max-width: 900px; margin: 30px auto; background: #f0f2f5; text-align: center; }
h1 { margin-bottom: 10px; }
#guide { background: #fff3cd; padding: 15px; border-radius: 8px; margin-bottom: 15px; text-align: left; }
#chat { border:1px solid #ccc; padding:15px; height:250px; overflow-y:auto; margin-bottom:15px; background:#fff; border-radius:10px; }
.message { margin:10px 0; }
.user { color:#1a73e8; }
.ai { color:#0f9d58; }
#status { display:flex; justify-content:center; align-items:center; gap:15px; font-size:1.2em; margin-bottom:10px; }
.icon { width:24px; height:24px; border-radius:50%; }
.listening .icon { background-color: orange; animation: pulse 1s infinite; }
.speaking .icon { background-color: green; animation: pulse 0.6s infinite; }
@keyframes pulse { 0% { transform: scale(1); opacity:0.7; } 50% { transform: scale(1.5); opacity:1; } 100% { transform: scale(1); opacity:0.7; } }
#waveform { width:100%; height:50px; background:#222; border-radius:5px; margin-bottom:10px; }
#controls { display:flex; justify-content:center; gap:10px; margin-bottom:15px; }
select,input,button { padding:10px; font-size:1em; border-radius:5px; }
button { cursor:pointer; }
#editor-container { display:flex; gap:10px; margin-top:15px; }
textarea, iframe { flex:1; height:300px; border-radius:8px; border:1px solid #ccc; font-family: monospace; font-size:14px; padding:10px; }
iframe { background:#fff; }
</style>
</head>
<body>

<h1>AI Website Refactor Assistant</h1>

<div id="guide">
<strong>How to Use & Speed Study of Programming:</strong>
<ul>
<li>Type or speak commands like "Make homepage responsive" or "Add dark mode".</li>
<li>Observe AI suggestions in chat and listen via voice output.</li>
<li>Edit code in the editor; live preview updates instantly.</li>
<li>Practice repeated refactoring to increase coding speed and understanding.</li>
<li>AI remembers your previous commands and adapts its suggestions over time.</li>
</ul>
</div>

<div id="status">
  <div class="icon"></div>
  <span id="statusText">Initializing...</span>
</div>

<canvas id="waveform"></canvas>

<div id="controls">
<select id="voiceStyle">
  <option value="default">Default</option>
  <option value="energetic">Energetic</option>
  <option value="calm">Calm</option>
  <option value="deep">Deep</option>
  <option value="robot">Robot</option>
</select>
<input type="text" id="userInput" placeholder="Type a command..." />
<button id="sendBtn">Send</button>
</div>

<div id="chat"></div>

<div id="editor-container">
<textarea id="codeEditor" placeholder="AI-refactored HTML/CSS/JS will appear here..."></textarea>
<iframe id="livePreview"></iframe>
</div>

<script>
const chat = document.getElementById('chat');
const userInput = document.getElementById('userInput');
const sendBtn = document.getElementById('sendBtn');
const status = document.getElementById('status');
const statusText = document.getElementById('statusText');
const waveform = document.getElementById('waveform');
const codeEditor = document.getElementById('codeEditor');
const livePreview = document.getElementById('livePreview');

const messageQueue = [];
let processingQueue = false;

// Waveform setup
const canvasCtx = waveform.getContext('2d');
let audioContext, analyser, dataArray, source;
async function initWaveform(){
  try{
    const stream = await navigator.mediaDevices.getUserMedia({audio:true});
    audioContext = new AudioContext();
    analyser = audioContext.createAnalyser();
    source = audioContext.createMediaStreamSource(stream);
    source.connect(analyser);
    analyser.fftSize = 256;
    dataArray = new Uint8Array(analyser.frequencyBinCount);
    drawWaveform();
  }catch(e){ console.error(e); }
}
function drawWaveform(){
  requestAnimationFrame(drawWaveform);
  if(!analyser) return;
  analyser.getByteTimeDomainData(dataArray);
  canvasCtx.fillStyle='#222';
  canvasCtx.fillRect(0,0,waveform.width,waveform.height);
  canvasCtx.lineWidth=2; canvasCtx.strokeStyle='#1a73e8'; canvasCtx.beginPath();
  const sliceWidth = waveform.width / dataArray.length;
  let x=0;
  for(let i=0;i<dataArray.length;i++){
    const v=dataArray[i]/128.0; const y=v*waveform.height/2;
    if(i===0) canvasCtx.moveTo(x,y); else canvasCtx.lineTo(x,y);
    x+=sliceWidth;
  }
  canvasCtx.lineTo(waveform.width,waveform.height/2);
  canvasCtx.stroke();
}

// Chat functions
function addMessage(text,sender){
  const div=document.createElement('div');
  div.className=`message ${sender}`;
  div.textContent=text;
  chat.appendChild(div);
  chat.scrollTop=chat.scrollHeight;
}

async function getAIResponse(message){
  try{
    const response = await fetch('/api/refactor',{
      method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({command:message})
    });
    const data = await response.json();
    codeEditor.value = data.response;
    updatePreview();
    return data.response;
  }catch(err){ console.error(err); return "Error communicating with AI tool."; }
}

async function processQueue(){
  if(processingQueue || messageQueue.length===0) return;
  processingQueue = true;
  while(messageQueue.length>0){
    const message = messageQueue.shift();
    addMessage(message,'user');
    const response = await getAIResponse(message);
    addMessage(response,'ai');
    status.className='speaking';
    statusText.textContent='💬 Speaking...';
    await speak(response);
    status.className='listening';
    statusText.textContent='🎤 Listening...';
  }
  processingQueue = false;
}
function enqueueMessage(message){
  messageQueue.push(message);
  processQueue();
}

function speak(text){
  return new Promise(resolve=>{
    const utterance = new SpeechSynthesisUtterance(text);
    const style = document.getElementById('voiceStyle').value;
    switch(style){
      case 'energetic': utterance.pitch=1.8; utterance.rate=1.4; break;
      case 'calm': utterance.pitch=0.7; utterance.rate=0.8; break;
      case 'deep': utterance.pitch=0.5; utterance.rate=1.0; break;
      case 'robot': utterance.pitch=1.0; utterance.rate=0.6; break;
      default: utterance.pitch=1.0; utterance.rate=1.0;
    }
    const voices = speechSynthesis.getVoices();
    if(voices.length>0) utterance.voice = voices[0];
    utterance.onend = resolve;
    speechSynthesis.speak(utterance);
  });
}

// Input handlers
sendBtn.addEventListener('click',()=>{const msg=userInput.value.trim();if(!msg)return; userInput.value=''; enqueueMessage(msg);});
userInput.addEventListener('keypress',e=>{if(e.key==='Enter'){const msg=userInput.value.trim();if(!msg)return; userInput.value=''; enqueueMessage(msg);}});

// Speech recognition
if(!('webkitSpeechRecognition' in window)&&!('SpeechRecognition' in window)){
  alert('Speech Recognition not supported');
  statusText.textContent='⚠️ Not supported';
}else{
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  const recognition = new SpeechRecognition();
  recognition.lang='en-US';
  recognition.interimResults=true;
  recognition.maxAlternatives=1;
  recognition.continuous=true;
  status.className='listening';
  statusText.textContent='🎤 Listening...';
  recognition.onresult=(event)=>{
    let transcript='';
    for(let i=event.resultIndex;i<event.results.length;i++){transcript+=event.results[i][0].transcript;}
    if(event.results[event.results.length-1].isFinal){enqueueMessage(transcript);}
  };
  recognition.onerror=(event)=>{console.error(event.error); statusText.textContent='⚠️ Error';};
  recognition.onend=()=>recognition.start();
  recognition.start();
}

// Code editor -> live preview
function updatePreview(){
  const previewDoc = livePreview.contentDocument || livePreview.contentWindow.document;
  previewDoc.open();
  previewDoc.write(codeEditor.value);
  previewDoc.close();
}

codeEditor.addEventListener('input',updatePreview);

// Waveform init & resize
initWaveform();
function resizeCanvas(){ waveform.width=waveform.clientWidth; waveform.height=waveform.clientHeight; }
window.addEventListener('resize',resizeCanvas);
resizeCanvas();
</script>

</body>
</html>
pip install stripe
import stripe

stripe.api_key = "sk_test_YOUR_SECRET_KEY"  # Replace with your secret key

@app.route('/api/create-checkout-session', methods=['POST'])
def create_checkout_session():
    data = request.json
    price = data.get("price", 10)  # Default $10
    try:
        session = stripe.checkout.Session.create(
            payment_method_types=['card'],
            line_items=[{
                'price_data': {
                    'currency': 'usd',
                    'product_data': {'name': 'AI Website Refactor Subscription'},
                    'unit_amount': int(price * 100),  # amount in cents
                },
                'quantity': 1,
            }],
            mode='payment',
            success_url='https://yourdomain.com/success',  # replace with your success page
            cancel_url='https://yourdomain.com/cancel',    # replace with your cancel page
        )
        return jsonify({'url': session.url})
    except Exception as e:
        return jsonify(error=str(e)), 500
<button id="payBtn">Subscribe / Pay $10</button>

<script src="https://js.stripe.com/v3/"></script>
<script>
const payBtn = document.getElementById('payBtn');
payBtn.addEventListener('click', async () => {
    try {
        const res = await fetch('/api/create-checkout-session', {
            method: 'POST',
            headers: {'Content-Type':'application/json'},
            body: JSON.stringify({price: 10})  // fee in USD
        });
        const data = await res.json();
        if(data.url) window.location = data.url; // redirect to Stripe Checkout
    } catch(e) { console.error(e); alert('Payment failed'); }
});
</script>
from flask import Flask, request, jsonify
from flask_cors import CORS
import json, os
import stripe

app = Flask(__name__)
CORS(app)

# Adaptive AI memory
MEMORY_FILE = "user_history.json"
if os.path.exists(MEMORY_FILE):
    with open(MEMORY_FILE, "r") as f:
        user_memory = json.load(f)
else:
    user_memory = {"commands": [], "responses": []}

# Stripe setup
stripe.api_key = "sk_test_YOUR_SECRET_KEY"  # Replace with your secret key

@app.route('/api/create-checkout-session', methods=['POST'])
def create_checkout_session():
    data = request.json
    price = data.get("price", 10)  # Default $10 fee
    try:
        session = stripe.checkout.Session.create(
            payment_method_types=['card'],
            line_items=[{
                'price_data': {
                    'currency': 'usd',
                    'product_data': {'name': 'AI Website Refactor Access'},
                    'unit_amount': int(price*100),
                },
                'quantity': 1,
            }],
            mode='payment',
            success_url='https://yourdomain.com/success?session_id={CHECKOUT_SESSION_ID}',
            cancel_url='https://yourdomain.com/cancel',
        )
        return jsonify({'url': session.url})
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route('/api/refactor', methods=['POST'])
def refactor():
    data = request.json
    command = data.get('command', '').strip()
    session_id = data.get('session_id', None)

    if not session_id:
        return jsonify({'response': "Payment required before using AI."}), 402

    # Verify payment
    try:
        session = stripe.checkout.Session.retrieve(session_id)
        if session.payment_status != 'paid':
            return jsonify({'response': "Payment not completed."}), 402
    except Exception as e:
        return jsonify({'response': f"Payment verification failed: {str(e)}"}), 402

    if not command:
        return jsonify({'response': "No command received."})

    try:
        result = adaptive_ai_process(command)
        # Save to memory
        user_memory["commands"].append(command)
        user_memory["responses"].append(result)
        with open(MEMORY_FILE, "w") as f:
            json.dump(user_memory, f, indent=2)
        return jsonify({'response': result})
    except Exception as e:
        return jsonify({'response': f"Error: {str(e)}"}), 500

# Adaptive AI function (teaching + learning)
def adaptive_ai_process(command):
    history_count = sum(1 for c in user_memory["commands"] if command.lower() in c.lower())
    note = ""
    if history_count > 0:
        note = "\n<!-- Note: Similar command detected, AI adapts to your style -->"

    if "responsive" in command.lower():
        code = """<!-- Responsive layout improvements -->
<style>
  body { max-width: 100%; padding: 10px; }
  @media (max-width: 600px) { nav { display: block; } }
</style>
<!-- Tip: Use media queries for mobile devices -->"""
        return code + note + "\n✅ Added media queries for responsiveness."
    elif "dark mode" in command.lower():
        code = """<!-- Dark mode CSS -->
<style>
  body { background-color: #121212; color: #eee; }
</style>
<!-- Tip: High-contrast colors improve readability -->"""
        return code + note + "\n🌙 Added dark mode CSS with teaching comments."
    else:
        code = "<!-- General improvements suggested by AI -->"
        return code + note + f"\n🤖 Analyzed '{command}' with inline teaching."

if __name__ == '__main__':
    app.run(debug=True)
<button id="payBtn">Pay $10 to Unlock AI</button>

<script src="https://js.stripe.com/v3/"></script>
<script>
let sessionId = null;  // Will store Stripe session after payment

document.getElementById('payBtn').addEventListener('click', async () => {
  try {
    const res = await fetch('/api/create-checkout-session', {
      method:'POST',
      headers:{'Content-Type':'application/json'},
      body:JSON.stringify({price:10})
    });
    const data = await res.json();
    if(data.url){
      // Redirect to Stripe Checkout
      window.location = data.url;
    }
  } catch(e){ console.error(e); alert('Payment failed'); }
});

// After successful payment, capture session_id from success URL
window.addEventListener('load', () => {
  const urlParams = new URLSearchParams(window.location.search);
  const sId = urlParams.get('session_id');
  if(sId){ 
    sessionId = sId;
    alert("Payment confirmed! You can now use the AI tool.");
  }
});

// When sending commands to AI, include session_id
async function sendCommandToAI(command){
  if(!sessionId){
    alert("Please pay to unlock AI features.");
    return;
  }
  const res = await fetch('/api/refactor', {
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body: JSON.stringify({command, session_id: sessionId})
  });
  const data = await res.json();
  // Display AI response in chat/editor as usual
}
</script>
@app.route('/api/suggest', methods=['POST'])
def suggest():
    """
    AI scans current code and suggests improvements.
    """
    data = request.json
    code = data.get('code', '')
    session_id = data.get('session_id', None)

    if not session_id:
        return jsonify({'response': "Payment required."}), 402

    # Verify payment
    try:
        session = stripe.checkout.Session.retrieve(session_id)
        if session.payment_status != 'paid':
            return jsonify({'response': "Payment not completed."}), 402
    except:
        return jsonify({'response': "Payment verification failed."}), 402

    # Simulate AI scanning code
    suggestions = []
    if "<style>" in code and "max-width" not in code:
        suggestions.append("Consider adding responsive design using media queries.")
    if "body { background-color" in code and "color:" not in code:
        suggestions.append("Set text color for better readability in dark/light backgrounds.")
    if len(suggestions)==0:
        suggestions.append("No major improvements detected, code looks good.")

    # Combine into response
    response_text = "<!-- AI Suggestions -->\n" + "\n".join([f"<!-- {s} -->" for s in suggestions])
    return jsonify({'response': response_text})
// Proactive AI suggestions every X seconds
setInterval(async () => {
  if(!sessionId) return;
  const code = codeEditor.value;
  const res = await fetch('/api/suggest', {
    method:'POST',
    headers:{'Content-Type':'application/json'},
    body: JSON.stringify({code, session_id: sessionId})
  });
  const data = await res.json();
  if(data.response){
    addMessage(data.response, 'ai'); // Show suggestions in chat
    // Optionally inject suggestions as comments in code editor
    if(!code.includes(data.response)){
      codeEditor.value = code + "\n\n" + data.response;
      updatePreview();
    }
  }
}, 20000); // every 20 seconds
<button id="exportBtn">Export Code</button>

<script>
document.getElementById('exportBtn').addEventListener('click', () => {
  const blob = new Blob([codeEditor.value], {type:'text/html'});
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download='refactored.html'; a.click();
  URL.revokeObjectURL(url);
});
</script>
ai_website_refactor_tool/
│
├── app.py                 # Backend Flask server
├── requirements.txt       # Python dependencies
├── templates/
│   └── index.html         # Frontend HTML + JS + CSS
├── static/
│   └── (optional JS/CSS if separated)
├── user_history.json      # Memory file for adaptive learning
└── boot.py                # "Boot Now" startup script
Flask==2.3.3
flask-cors==3.1.1
stripe==11.10.0
import subprocess
import os
import webbrowser

# Step 1: Check if virtual environment exists, create if not
if not os.path.exists('venv'):
    print("Creating virtual environment...")
    subprocess.run(['python', '-m', 'venv', 'venv'])

# Step 2: Activate virtual environment & install dependencies
print("Installing dependencies...")
if os.name == 'nt':  # Windows
    subprocess.run(['venv\\Scripts\\pip', 'install', '-r', 'requirements.txt'])
else:  # macOS / Linux
    subprocess.run(['venv/bin/pip', 'install', '-r', 'requirements.txt'])

# Step 3: Launch Flask app
print("Starting AI Website Refactor Tool...")
if os.name == 'nt':
    proc = subprocess.Popen(['venv\\Scripts\\python', 'app.py'])
else:
    proc = subprocess.Popen(['venv/bin/python', 'app.py'])

# Step 4: Open browser automatically
import time
time.sleep(3)  # wait for server to start
webbrowser.open("http://127.0.0.1:5000")
python boot.py
flask==2.3.3
flask-cors==3.1.1
stripe==11.10.0
pyngrok==6.2.1
import subprocess
import os
import time
import webbrowser
from pyngrok import ngrok

# Step 1: Setup virtual environment and dependencies (same as before)
if not os.path.exists('venv'):
    print("Creating virtual environment...")
    subprocess.run(['python', '-m', 'venv', 'venv'])

print("Installing dependencies...")
if os.name == 'nt':
    subprocess.run(['venv\\Scripts\\pip', 'install', '-r', 'requirements.txt'])
else:
    subprocess.run(['venv/bin/pip', 'install', '-r', 'requirements.txt'])

# Step 2: Start Flask app
print("Starting AI Website Refactor Tool server...")
if os.name == 'nt':
    proc = subprocess.Popen(['venv\\Scripts\\python', 'app.py'])
else:
    proc = subprocess.Popen(['venv/bin/python', 'app.py'])

time.sleep(3)  # wait for server to start

# Step 3: Open ngrok tunnel
print("Creating public link via ngrok...")
public_url = ngrok.connect(5000)
print(f"Your AI Website Refactor Tool is now publicly reachable at: {public_url}")

# Step 4: Open in default browser
webbrowser.open(public_url)
python boot.py
Your AI Website Refactor Tool is now publicly reachable at: https://abcd-1234.ngrok.io
ai_website_refactor_tool/
│
├── app.py                 # Backend Flask server
├── boot.py                # One-click startup + ngrok public link
├── requirements.txt       # Dependencies
├── templates/
│   └── index.html         # Full frontend with all features inline
├── user_history.json      # Adaptive learning memory (auto-generated)
Flask==2.3.3
flask-cors==3.1.1
stripe==11.10.0
pyngrok==6.2.1
import subprocess
import os
import time
import webbrowser
from pyngrok import ngrok

# Step 1: Setup virtual environment & dependencies
if not os.path.exists('venv'):
    print("Creating virtual environment...")
    subprocess.run(['python', '-m', 'venv', 'venv'])

print("Installing dependencies...")
if os.name == 'nt':
    subprocess.run(['venv\\Scripts\\pip', 'install', '-r', 'requirements.txt'])
else:
    subprocess.run(['venv/bin/pip', 'install', '-r', 'requirements.txt'])

# Step 2: Start Flask app
print("Starting AI Website Refactor Tool server...")
if os.name == 'nt':
    proc = subprocess.Popen(['venv\\Scripts\\python', 'app.py'])
else:
    proc = subprocess.Popen(['venv/bin/python', 'app.py'])

time.sleep(3)  # wait for server

# Step 3: Create ngrok public link
print("Creating public link via ngrok...")
public_url = ngrok.connect(5000)
print(f"Your AI Website Refactor Tool is now publicly reachable at: {public_url}")

# Step 4: Open browser
webbrowser.open(public_url)
from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
import json, os
import stripe

app = Flask(__name__)
CORS(app)

MEMORY_FILE = "user_history.json"
if os.path.exists(MEMORY_FILE):
    with open(MEMORY_FILE, "r") as f:
        user_memory = json.load(f)
else:
    user_memory = {"commands": [], "responses": []}

# Stripe setup
stripe.api_key = "sk_test_YOUR_SECRET_KEY"  # Replace with your key

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/create-checkout-session', methods=['POST'])
def create_checkout_session():
    data = request.json
    price = data.get("price", 10)
    try:
        session = stripe.checkout.Session.create(
            payment_method_types=['card'],
            line_items=[{
                'price_data': {
                    'currency': 'usd',
                    'product_data': {'name': 'AI Website Refactor Access'},
                    'unit_amount': int(price*100),
                },
                'quantity': 1,
            }],
            mode='payment',
            success_url='https://yourdomain.com/success?session_id={CHECKOUT_SESSION_ID}',
            cancel_url='https://yourdomain.com/cancel',
        )
        return jsonify({'url': session.url})
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route('/api/refactor', methods=['POST'])
def refactor():
    data = request.json
    command = data.get('command','').strip()
    session_id = data.get('session_id', None)

    if not session_id:
        return jsonify({'response': "Payment required."}), 402
    try:
        session = stripe.checkout.Session.retrieve(session_id)
        if session.payment_status != 'paid':
            return jsonify({'response': "Payment not completed."}), 402
    except:
        return jsonify({'response': "Payment verification failed."}), 402

    if not command:
        return jsonify({'response': "No command received."})

    result = adaptive_ai_process(command)
    user_memory["commands"].append(command)
    user_memory["responses"].append(result)
    with open(MEMORY_FILE,'w') as f:
        json.dump(user_memory,f,indent=2)
    return jsonify({'response': result})

@app.route('/api/suggest', methods=['POST'])
def suggest():
    data = request.json
    code = data.get('code','')
    session_id = data.get('session_id', None)

    if not session_id:
        return jsonify({'response': "Payment required."}), 402
    try:
        session = stripe.checkout.Session.retrieve(session_id)
        if session.payment_status != 'paid':
            return jsonify({'response': "Payment not completed."}), 402
    except:
        return jsonify({'response': "Payment verification failed."}), 402

    suggestions=[]
    if "<style>" in code and "max-width" not in code:
        suggestions.append("Consider adding responsive design using media queries.")
    if "body { background-color" in code and "color:" not in code:
        suggestions.append("Set text color for better readability in dark/light backgrounds.")
    if len(suggestions)==0:
        suggestions.append("No major improvements detected, code looks good.")
    response_text = "<!-- AI Suggestions -->\n" + "\n".join([f"<!-- {s} -->" for s in suggestions])
    return jsonify({'response': response_text})

def adaptive_ai_process(command):
    history_count = sum(1 for c in user_memory["commands"] if command.lower() in c.lower())
    note = ""
    if history_count>0:
        note="\n<!-- Note: Similar command detected, AI adapts to your style -->"

    if "responsive" in command.lower():
        code = """<!-- Responsive layout improvements -->
<style>
  body { max-width: 100%; padding: 10px; }
  @media (max-width: 600px) { nav { display: block; } }
</style>
<!-- Tip: Use media queries for mobile devices -->"""
        return code+note+"\n✅ Added media queries for responsiveness."
    elif "dark mode" in command.lower():
        code = """<!-- Dark mode CSS -->
<style>
  body { background-color: #121212; color: #eee; }
</style>
<!-- Tip: High-contrast colors improve readability -->"""
        return code+note+"\n🌙 Added dark mode CSS with teaching comments."
    else:
        code = "<!-- General improvements suggested by AI -->"
        return code+note+f"\n🤖 Analyzed '{command}' with inline teaching."

if __name__=='__main__':
    app.run(debug=True)
python boot.py
ai_website_refactor_tool/
├── app.py
├── boot.py
├── requirements.txt
├── templates/
│   └── index.html
└── user_history.json  (optional, can be created later)
ai_website_refactor_tool/
├── app.py
├── boot.py
├── requirements.txt
├── templates/
│   └── index.html
└── user_history.json  (optional, can be created later)
import subprocess
import os
import time
import webbrowser
from pyngrok import ngrok

# Step 1: Setup virtual environment & dependencies
if not os.path.exists("venv"):
    print("Creating virtual environment...")
    subprocess.run(["python", "-m", "venv", "venv"])

print("Installing dependencies...")
if os.name == "nt":
    subprocess.run(["venv\\Scripts\\pip", "install", "-r", "requirements.txt"])
else:
    subprocess.run(["venv/bin/pip", "install", "-r", "requirements.txt"])

# Step 2: Start Flask app
print("Starting AI Website Refactor Tool server...")
if os.name == "nt":
    proc = subprocess.Popen(["venv\\Scripts\\python", "app.py"])
else:
    proc = subprocess.Popen(["venv/bin/python", "app.py"])

time.sleep(3)  # wait for server

# Step 3: Create ngrok public link
print("Creating public link via ngrok...")
public_url = ngrok.connect(5000)
print(f"Your AI Website Refactor Tool is now publicly reachable at: {public_url}")

# Step 4: Open browser
webbrowser.open(str(public_url))
python boot.py
from flask import Flask, render_template, request, jsonify
import openai
import json
import os

app = Flask(__name__)

# Load API key
openai.api_key = os.getenv("OPENAI_API_KEY")

# History memory (learns over time)
HISTORY_FILE = "user_history.json"
if os.path.exists(HISTORY_FILE):
    with open(HISTORY_FILE, "r", encoding="utf-8") as f:
        user_history = json.load(f)
else:
    user_history = []

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/refactor", methods=["POST"])
def refactor():
    data = request.json
    code = data.get("code", "")
    command = data.get("command", "")

    # Append to history
    user_history.append({"command": command, "code": code})
    with open(HISTORY_FILE, "w", encoding="utf-8") as f:
        json.dump(user_history, f, indent=2)

    # Call OpenAI API
    try:
        response = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": "You are an AI refactoring and teaching assistant."},
                {"role": "user", "content": f"Refactor this code: {code}\n\nInstruction: {command}"}
            ]
        )
        ai_code = response["choices"][0]["message"]["content"]
    except Exception as e:
        ai_code = f"Error: {e}"

    return jsonify({"refactored": ai_code})

if __name__ == "__main__":
    app.run(port=5000, debug=True)
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>AI Website Refactor Tool</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f7f7f7; padding: 20px; }
    #editor { width: 100%; height: 200px; }
    #preview { width: 100%; height: 200px; border: 1px solid #ccc; background: white; }
    #waveform { width: 100%; height: 60px; background: #222; margin-top: 10px; }
    button { padding: 10px 15px; margin: 5px; border-radius: 8px; cursor: pointer; }
    #status { margin-top: 10px; }
  </style>
</head>
<body>
  <h1>AI Website Refactor Tool</h1>

  <textarea id="editor" placeholder="Paste your HTML, CSS, or JS here..."></textarea><br>
  <button id="refactorBtn">Refactor with AI</button>
  <button id="speakBtn">🎤 Voice Command</button>
  <button id="listenBtn">🔊 Read Response</button>

  <div id="status">Idle</div>
  <canvas id="waveform"></canvas>

  <h3>Live Preview</h3>
  <iframe id="preview"></iframe>

  <script>
    const codeEditor = document.getElementById("editor");
    const refactorBtn = document.getElementById("refactorBtn");
    const speakBtn = document.getElementById("speakBtn");
    const listenBtn = document.getElementById("listenBtn");
    const status = document.getElementById("status");
    const waveform = document.getElementById("waveform");
    const livePreview = document.getElementById("preview");

    let lastResponse = "";

    async function sendRefactor(command) {
      const response = await fetch("/refactor", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ code: codeEditor.value, command })
      });
      const data = await response.json();
      codeEditor.value = data.refactored;
      updatePreview();
      lastResponse = data.refactored;
    }

    refactorBtn.onclick = () => {
      sendRefactor("Refactor this code");
    };

    // Voice input
    speakBtn.onclick = () => {
      const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
      const recognition = new SpeechRecognition();
      recognition.lang = "en-US";
      recognition.interimResults = true;
      recognition.maxAlternatives = 1;
      recognition.continuous = true;

      status.textContent = "🎤 Listening...";
      recognition.onresult = (event) => {
        let transcript = "";
        for (let i = event.resultIndex; i < event.results.length; i++) {
          transcript += event.results[i][0].transcript;
        }
        if (event.results[event.results.length - 1].isFinal) {
          sendRefactor(transcript);
        }
      };
      recognition.onerror = (event) => {
        console.error(event.error);
        status.textContent = "⚠️ Error";
      };
      recognition.onend = () => recognition.start();
      recognition.start();
    };

    // Voice output
    listenBtn.onclick = () => {
      if (!lastResponse) return;
      const synth = window.speechSynthesis;
      const utterance = new SpeechSynthesisUtterance(lastResponse);
      synth.speak(utterance);
    };

    // Live preview
    function updatePreview() {
      const previewDoc = livePreview.contentDocument || livePreview.contentWindow.document;
      previewDoc.open();
      previewDoc.write(codeEditor.value);
      previewDoc.close();
    }
    codeEditor.addEventListener("input", updatePreview);
  </script>
</body>
</html>
flask
openai
pyngrok
import subprocess
import os
import time
import webbrowser
from pyngrok import ngrok

# Step 1: Setup virtual environment & dependencies
if not os.path.exists("venv"):
    print("Creating virtual environment...")
    subprocess.run(["python", "-m", "venv", "venv"])

print("Installing dependencies...")
if os.name == "nt":
    subprocess.run(["venv\\Scripts\\pip", "install", "-r", "requirements.txt"])
else:
    subprocess.run(["venv/bin/pip", "install", "-r", "requirements.txt"])

# Step 2: Start Flask app
print("Starting AI Website Refactor Tool server...")
if os.name == "nt":
    proc = subprocess.Popen(["venv\\Scripts\\python", "app.py"])
else:
    proc = subprocess.Popen(["venv/bin/python", "app.py"])

time.sleep(3)  # wait for server

# Step 3: Create ngrok public link
print("Creating public link via ngrok...")
public_url = ngrok.connect(5000)
print(f"Your AI Website Refactor Tool is now publicly reachable at: {public_url}")

# Step 4: Open browser
webbrowser.open(str(public_url))
python boot.py
print("Boot script test")
python boot.py


