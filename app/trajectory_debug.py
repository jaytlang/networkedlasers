import trajectory_planner as tp
#import laser as ls
import cv2
import numpy as np

img = cv2.imread('app/nyan_cat.png')
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)        # Converting the image to grayscale.
gray_filtered = cv2.bilateralFilter(gray, 7, 50, 50)  # Smoothing without removing edges.
edges = cv2.Canny(gray, 60, 120)                      # Applying the canny filter
edges_filtered = cv2.Canny(gray_filtered, 60, 120)
trajectory, degeneracies = tp.calculate_trajectory(edges_filtered)
tp.animate_trajectory_with_jumps(np.zeros_like(img), trajectory, 1)