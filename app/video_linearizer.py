import cv2
import numpy as np
import trajectory_planner as tp
import os
import cProfile
import pandas as pd

def save_frame(path, image):
    files = [i for i in os.listdir(path) if '.png' in i]
    filename = f'{path}/{len(files)}.png'
    cv2.imwrite(filename, image)

def save_trajectory(path, trajectory):
    files = [i for i in os.listdir(path) if '.csv' in i]
    filename = f'{path}/{len(files)}.csv'
    pd.DataFrame(trajectory.astype(int)).to_csv(filename, header=False)

cv2.setUseOptimized(True)

cap = cv2.VideoCapture('apple.jpg') # If the input is the camera, pass 0 instead of the video file name

if (cap.isOpened() == False):
  print("Error opening video stream or file")

while(cap.isOpened()):
  ret, frame = cap.read()
  if ret == True:

    # Canny filtering
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)        # Converting the image to grayscale.
    gray_filtered = cv2.bilateralFilter(gray, 7, 50, 50)  # Smoothing without removing edges.
    edges = cv2.Canny(gray, 60, 120)                      # Applying the canny filter
    edges_filtered = cv2.Canny(gray_filtered, 60, 120)

    # Trajectory Planning
    blur = cv2.blur(frame,(5,5))
    trajectory, degeneracies = tp.calculate_trajectory(edges_filtered)
    colorized_trajectory = tp.colorize_trajectory(blur, trajectory)
    rendered_trajectory = tp.draw_trajectory(np.zeros_like(frame), colorized_trajectory)

    # Stacking the images to print them together for comparison
    edges_filtered_colored = cv2.cvtColor(edges_filtered, cv2.COLOR_GRAY2BGR)
    #planned_colored = cv2.cvtColor(planned, cv2.COLOR_GRAY2BGR)
    images = np.hstack((frame, edges_filtered_colored, rendered_trajectory))

    # Display the resulting frame
    cv2.imshow('Frame', images)
    save_frame('output', images)
    save_trajectory('output', colorized_trajectory)

    if cv2.waitKey(25) & 0xFF == ord('q'): # Press Q to exit 
      break

  else:
    break

cap.release()
cv2.destroyAllWindows()