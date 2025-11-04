from fastapi import FastAPI

app = FastAPI()

@app.get('/')
def read_root():
    return {'status': 'White-Label AI Backend Running'}

@app.post('/run')
def run_model():
    return {'result': 'AI model executed successfully'}
