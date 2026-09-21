import json
import heapq
import math
import time

class PriorityQueue:
    def __init__(self):
        self.elements = []
        self.counter = 0

    def enqueue(self, item, priority, secondary=0.0):
        # Struktur tuple: (priority, secondary, counter, item)
        heapq.heappush(self.elements, (priority, secondary, self.counter, item))
        self.counter += 1

    def dequeue(self):
        priority, secondary, counter, item = heapq.heappop(self.elements)
        return item, priority, secondary

    def is_empty(self):
        return len(self.elements) == 0

    def to_list(self):
        return [entry[3] for entry in sorted(self.elements, key=lambda x: (x[0], x[1], x[2]))]

def zero_heuristic(current, goal):
    return 0.0

def manhattan_heuristic(current, goal):
    return float(abs(current['x'] - goal['x']) + abs(current['y'] - goal['y']))

def euclidean_heuristic(current, goal):
    dx = current['x'] - goal['x']
    dy = current['y'] - goal['y']
    return float(math.sqrt(dx * dx + dy * dy))

def get_heuristic(name):
    if name == 'manhattan':
        return manhattan_heuristic
    elif name == 'euclidean':
        return euclidean_heuristic
    return zero_heuristic

def key(cell):
    return f"{cell['x']},{cell['y']}"

def same_cell(a, b):
    return a['x'] == b['x'] and a['y'] == b['y']

class Grid:
    def __init__(self, map_data):
        self.map_data = map_data
        self.rows = len(map_data)
        self.cols = len(map_data[0]) if self.rows > 0 else 0

    def is_inside(self, cell):
        return 0 <= cell['x'] < self.cols and 0 <= cell['y'] < self.rows

    def get_terrain(self, cell):
        return self.map_data[cell['y']][cell['x']]

    def is_passable(self, cell):
        return self.is_inside(cell) and self.get_terrain(cell) != '#'

    def get_step_cost(self, cell):
        return 7 if self.get_terrain(cell) == 'R' else 1

    def get_neighbors(self, cell):
        moves = [{'x': 0, 'y': -1}, {'x': 0, 'y': 1}, {'x': -1, 'y': 0}, {'x': 1, 'y': 0}]
        neighbors = []
        for m in moves:
            next_cell = {'x': cell['x'] + m['x'], 'y': cell['y'] + m['y']}
            if self.is_passable(next_cell):
                neighbors.append(next_cell)
        return neighbors

def reconstruct_path(parent, start, goal):
    path = []
    curr_key = key(goal)
    start_key = key(start)
    while curr_key:
        coords = list(map(int, curr_key.split(',')))
        path.append({'x': coords[0], 'y': coords[1]})
        if curr_key == start_key:
            break
        curr_key = parent.get(curr_key)
    
    if not path or path[-1]['x'] != start['x'] or path[-1]['y'] != start['y']:
        return []
    path.reverse()
    return path

def search_path(map_data, start, goal, algorithm='ucs', heuristic_name='zero'):
    grid = Grid(map_data)
    heuristic = get_heuristic(heuristic_name)
    start_time = time.perf_counter()

    g_score = {}
    parent = {}
    closed = set()
    frontier = PriorityQueue()
    expansion_order = []

    start_key = key(start)
    g_score[start_key] = 0.0
    start_h = heuristic(start, goal)
    start_priority = 0.0 if algorithm == 'ucs' else start_h

    frontier.enqueue(start, start_priority, 0.0 if algorithm == 'ucs' else start_h)
    expanded_nodes = 0

    while not frontier.is_empty():
        current, priority, secondary = frontier.dequeue()
        current_key = key(current)
        
        if current_key in closed:
            continue
            
        expanded_nodes += 1
        expansion_order.append({
            'x': current['x'], 'y': current['y'],
            'level': priority, 'g': g_score[current_key]
        })

        if same_cell(current, goal):
            path = reconstruct_path(parent, start, goal)
            search_time_ms = (time.perf_counter() - start_time) * 1000.0
            return {
                'found': True, 'path': path, 'expandedNodes': expanded_nodes,
                'expandedNodesList': list(closed) + [current_key],
                'expansionOrder': expansion_order, 'frontierNodes': frontier.to_list(),
                'pathCost': g_score[current_key], 'pathLength': max(0, len(path) - 1),
                'searchTimeMs': search_time_ms, 'start': start, 'goal': goal
            }

        closed.add(current_key)
        for next_cell in grid.get_neighbors(current):
            next_key = key(next_cell)
            new_g = g_score[current_key] + grid.get_step_cost(next_cell)

            if new_g < g_score.get(next_key, float('inf')):
                g_score[next_key] = new_g
                parent[next_key] = current_key
                h = heuristic(next_cell, goal)
                p = new_g if algorithm == 'ucs' else new_g + h
                s = 0.0 if algorithm == 'ucs' else h
                frontier.enqueue(next_cell, p, s)

    search_time_ms = (time.perf_counter() - start_time) * 1000.0
    return {
        'found': False, 'path': [], 'expandedNodes': expanded_nodes,
        'expandedNodesList': list(closed), 'expansionOrder': expansion_order,
        'frontierNodes': [], 'pathCost': None, 'pathLength': 0,
        'searchTimeMs': search_time_ms, 'start': start, 'goal': goal
    }

# FUNGSI WRAPPER UNTUK BERKOMUNIKASI DENGAN JAVASCRIPT
def search_path_json(map_data_json, start_json, goal_json, algorithm, heuristic_name):
    map_data = json.loads(map_data_json)
    start = json.loads(start_json)
    goal = json.loads(goal_json)
    result = search_path(map_data, start, goal, algorithm, heuristic_name)
    return json.dumps(result)