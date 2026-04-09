from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from samsung_tv import SamsungTV
import uvicorn

app = FastAPI(title='Samsung TV Control API')
tv = None

def get_tv():
    global tv
    if tv is None:
        tv = SamsungTV()
    return tv

class KeyRequest(BaseModel):
    key: str

class AppRequest(BaseModel):
    name: str

class TextRequest(BaseModel):
    text: str

class WakeRequest(BaseModel):
    mac: str = None

@app.post('/key')
def send_key(req: KeyRequest):
    result = get_tv().send_key(req.key)
    return {'ok': result}

@app.post('/app')
def launch_app(req: AppRequest):
    result = get_tv().launch_app(req.name)
    return {'ok': result}

@app.post('/text')
def send_text(req: TextRequest):
    result = get_tv().send_text(req.text)
    return {'ok': result}

@app.get('/info')
def get_info():
    return get_tv().get_tv_info()

@app.post('/wake')
def wake(req: WakeRequest):
    result = get_tv().wake_tv(req.mac)
    return {'ok': result}

@app.get('/apps')
def list_apps():
    return get_tv().list_installed_apps()

if __name__ == '__main__':
    uvicorn.run(app, host='0.0.0.0', port=5555)
