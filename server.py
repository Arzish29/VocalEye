from flask import Flask, request, jsonify
import cv2
import numpy as np
from PIL import Image
import io
from ultralytics import YOLO

app = Flask(__name__)

# Load pretrained YOLOv8 model
model = YOLO("yolov8n.pt")  # small, fast model

@app.route('/')
def home():
    return "Backend Server is Running!"

@app.route('/detect', methods=['POST'])
def detect():
    if 'image' not in request.files:
        return jsonify({"error": "No image provided"}), 400

    image_file = request.files['image']
    image_bytes = image_file.read()

    # Convert bytes to OpenCV image
    pil_image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    open_cv_image = np.array(pil_image)
    open_cv_image = cv2.cvtColor(open_cv_image, cv2.COLOR_RGB2BGR)

    # Run object detection
    results = model(open_cv_image)[0]

    detected_objects = []
    for box in results.boxes:
        cls_id = int(box.cls[0])
        conf = float(box.conf[0])
        name = model.names[cls_id]
        detected_objects.append({"name": name, "confidence": conf})

    return jsonify({"objects": detected_objects})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

