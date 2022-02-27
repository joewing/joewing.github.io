
export class Example {
  title: string;
  path: string;

  constructor(title: string, path: string) {
    this.title = title;
    this.path = path;
  }
}

export const EXAMPLES: Array<Example> = [
  new Example('Hello', 'hello.q2p'),
  new Example('Hunt the Wumpus', 'wump.q2p'),
  new Example('Invaders', 'invaders.q2p'),
  new Example('Life', 'life.q2p'),
  new Example('Maze', 'maze.q2p'),
  new Example('Pi', 'pi.q2p'),
  new Example('Pong', 'pong.q2p'),
  new Example('Sieve', 'sieve.q2p'),
  new Example('Snake', 'snake.q2p'),
  new Example('Tetris', 'tetris.q2p'),
];

