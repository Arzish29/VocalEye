import requests

url = "http://192.168.1.11:5000/detect"
files = {'image': open("test_image.jpg", "rb")}

response = requests.post(url, files=files)
print(response.json())
