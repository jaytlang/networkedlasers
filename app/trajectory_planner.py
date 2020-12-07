# Laser Trajectory Planning Library
#
# Used to turn images into laser trajectories, which are then sent over the network to a TCP offload engine
# running on a Nexsys 4 DDR, which then pushes image data out to a RGB laser.
#
# fischerm@mit.edu, Fall 2020

import cv2
import numpy as np

# Export Functions
def draw_trajectory(template, trajectory, color=(255,0,0), popup=False):
    _, depth = trajectory.shape

    if depth == 2: # trajectory is monochrome, no color information is present in the row
        formatted_contour = np.expand_dims(trajectory, 1)
        render = cv2.drawContours(template, formatted_contour, -1, color, 1)

        if popup:
            cv2.imshow('render.png', render)
            cv2.waitKey()
        return render

    if depth == 5: # trajectory is colored, BGR values are present
        render = template
        for row in trajectory:
            y, x, b, g, r = row
            render[x, y] = [b, g, r]

        if popup:
            cv2.imshow('render.png', render)
            cv2.waitKey()
        return render

def animate_trajectory(template, contour, speed):
    formatted_contour = np.expand_dims(contour, 1)
    for i in range(0, len(formatted_contour), speed):
        img = cv2.drawContours(template, formatted_contour[:i], -1, (0,255,0), 1)
        width = img.shape[0]
        height = img.shape[1]
        img = cv2.resize(img, (width*3, height*3), interpolation = cv2.INTER_AREA)
        cv2.imshow('labeled.png', img)

        # Press Q on keyboard to  exit
        if cv2.waitKey(5) & 0xFF == ord('q'):
            break

def animate_trajectory_with_jumps(template, contour, speed):
    formatted_contour = np.expand_dims(contour, 1)
    total_jumps = 0
    total_jump_distance = 0

    for i in range(0, len(formatted_contour) - 1, speed):
        current_x = contour[i][0]
        current_y = contour[i][1]
        next_x = contour[i+1][0]
        next_y = contour[i+1][1]

        if is_adjacent(current_x, current_y, next_x, next_y):
            template[current_y, current_x] = (0, 255, 0)

        else:
            template = cv2.line(template,(current_x, current_y),(next_x, next_y),(0,0,255),1)
            total_jumps += 1
            total_jump_distance += np.sqrt((current_x-next_x)**2 + (current_y-next_y)**2)

        width = template.shape[0]
        height = template.shape[1]
        thicco = cv2.resize(template, (width*3, height*3), interpolation = cv2.INTER_AREA)
        cv2.imshow('labeled.png', thicco)
        cv2.imwrite('output.png', thicco)
        print(f'total jumps: {total_jumps}')
        print(f'total distance jumped: {total_jump_distance}px')

        # Press Q on keyboard to  exit
        if cv2.waitKey(25) & 0xFF == ord('q'):
            break

    
# Image Processing Functions
def colorize_trajectory(img, trajectory):
    num_points, _ = trajectory.shape
    colors = np.zeros((num_points, 3), dtype=int)

    for i in range(num_points - 1):
        y_current, x_current = trajectory[i]
        y_next, x_next = trajectory[i+1]
        
        if is_adjacent(x_current, y_current, x_next, y_next):
            colors[i] = img[x_current, y_current]
        
        else:
            colors[i] = (0,0,0)
    return np.hstack((trajectory, colors))

def calculate_trajectory(img, start_x=0, start_y=0):
    # calculate the trajectory for the entire image, and export as list of x,y points
    # also export an array of all the degenercies found in the image
    binary_img = cv2.threshold(img, 127, 255, cv2.THRESH_BINARY)[1]  # ensure binary
    contours = find_contours(binary_img)

    # if there aren't any contours in the image, just return nothing
    if len(contours) == 0:
        return np.asarray([[0, 0]]), np.asarray([])

    current_x = start_x
    current_y = start_y

    remaining_contours = [contour.tolist() for contour in contours]
    output_trajectory = []
    degeneracies = []

    while remaining_contours:
        next_contour_unordered = get_nearest_contour(remaining_contours, current_x, current_y)
        next_contour_ordered = get_reordered_contour(next_contour_unordered.tolist(), current_x, current_y)
        next_contour_ordered, next_degeneracies = order_contour(next_contour_ordered)
        remaining_contours.remove(next_contour_unordered.tolist())
        output_trajectory.append(next_contour_ordered)

        if next_degeneracies.tolist():
            for degeneracy in next_degeneracies.tolist():
                degeneracies.append(degeneracy)

        current_x = output_trajectory[-1][-1][0]
        current_y = output_trajectory[-1][-1][1]

    return np.vstack(tuple(output_trajectory)), np.asarray(degeneracies)

def find_contours(img):
    # splits image into a list of numpy arrays, each corresponding to a contour in the image
    num_labels, labels = cv2.connectedComponents(img)
    return [np.column_stack((np.where(labels == i)[::-1])) for i in range(1, np.max(labels))]

def order_contour(contour):
    # take first element of contour as starting, then keep finding adjacent points until the curve has been linearized
    # return contour afterwards as numpy array, as well as degeneracies
    remaining_points = contour.tolist()
    output_trajectory = [remaining_points[0]]

    degeneracies = [] # tracks the degenercies found

    while remaining_points:
        current_x = output_trajectory[-1][0] # the point that we're searching for
        current_y = output_trajectory[-1][1]

        # if this is the last point, add it to trajectory and exit
        if len(remaining_points) == 1:
            output_trajectory.append(remaining_points[0])
            remaining_points.remove(remaining_points[0])

        # if this isn't the last point, find the next adjacent point
        else:
            next_point = find_next_point(remaining_points, current_x, current_y)

            if(next_point): # if there is a point adjacent to the current one
                output_trajectory.append(next_point)
                remaining_points.remove(next_point)

            else:
                # found a degeneracy, back up algorithim to the most recent point that has an adjacency
                #print(f'Found degeneracy at ({current_x},{current_y})')

                degeneracies.append([current_x, current_y])
                for point in output_trajectory[::-1]:
                    if find_next_point(remaining_points, point[0], point[1]):
                        output_trajectory.append(point)
                        break

    return np.asarray(output_trajectory), np.asarray(degeneracies)

def find_next_point(points, x, y):
    # Given some point in the contour, find the next (adjacent) point in the contour

    # try using four_level adjacency first, and if nothing is found, use eight_level adjacency
    for point in points:
        if is_adjacent(x, y, point[0], point[1], adjacency='four_level'):
            return point


    for point in points:
        if is_adjacent(x, y, point[0], point[1], adjacency='eight_level'):
            return point

    return None

def is_adjacent(x1, y1, x2, y2, adjacency='eight_level'):
    if(x1 == x2 and y1 ==y2):
        return False

    if(adjacency == 'four_level'):
        if (x1 == x2 and abs(y1-y2) == 1):
            return True
        if (y1 == y2 and abs(x1-x2) == 1):
            return True
        return False

    if(adjacency == 'eight_level'):
        if(abs(x1-x2) <= 1 and abs(y1-y2) <= 1):
            return True
        return False

def get_reordered_contour(contour, x, y):
    # returns the passed contour, just reordered such that the first point is the one closest to the x,y point passed in

    # figure out what index the nearest point occurs at
    closest_point = get_nearest_point([contour], x, y).tolist()[::-1]
    contour_list = contour#.tolist()

    index = contour_list.index(closest_point)
    reordered_contour = [contour_list[i%len(contour_list)] for i in range(index, index + len(contour_list))]
    return np.asarray(reordered_contour)

def get_nearest_contour(contours, x, y):
    # get contour corresponding to nearest point

    # turns out numpy doesn't have a built in method for seeing if a row is in a matrix,
    # so instead we have to convert to a list first, which is slow. big sad.
    closest_point = get_nearest_point(contours, x, y).tolist()[::-1]
    contours_list = contours #[contour.tolist() for contour in contours]

    for contour in contours_list:
        if closest_point in contour:
            return np.asarray(contour)

def get_nearest_point(contours, x, y):
    ### returns the nearest point on a contour to a provided x,y point
    # put all x, y points into a list
    all_points = np.vstack(tuple(contours))

    # compute distances of all points
    dist_squared = lambda row: (row[0]-x)**2 + (row[1]-y)**2
    dist_squared_map = np.apply_along_axis(dist_squared, axis=1, arr=all_points)

    # find closest point
    closest_point = all_points[np.argmin(dist_squared_map)]
    return np.flip(closest_point) # for some reason x and y are reversed, so we should flip it before sending it out