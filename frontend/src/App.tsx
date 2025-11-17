import reactLogo from './assets/react.svg'
import viteLogo from '/vite.svg'
import './App.css'
import { useState, useEffect } from 'react'

type Status = "loading" | "ok" | "error" | null;
const BASE_URL = import.meta.env.VITE_API_BASE_URL;

function App() {
  const [count, setCount] = useState(0)

  const [status, setStatus] = useState<Status>(null);

  useEffect(() => {
    const fetchHealth = async () => {
      setStatus("loading");
      try {
        const res = await fetch(`${BASE_URL}/health`);
        const data = await res.json();
        console.log(data);
        if (res.ok) setStatus("ok");
      } catch (error) {
        console.error(error);
        setStatus("error");
      }
    }

    fetchHealth();
  }, []);

  return (
    <>
      <div>
        <a href="https://vite.dev" target="_blank">
          <img src={viteLogo} className="logo" alt="Vite logo" />
        </a>
        <a href="https://react.dev" target="_blank">
          <img src={reactLogo} className="logo react" alt="React logo" />
        </a>
      </div>
      <h1>Vite + React</h1>
      <div className="card">
        <button onClick={() => setCount((count) => count + 1)}>
          count is {count}
        </button>
        <p>
          Edit <code>src/App.tsx</code> and save to test HMR
        </p>
      </div>
      <p className="read-the-docs">
        Click on the Vite and React logos to learn more
      </p>
      <p>
        Health: {status}
      </p>
    </>
  )
}

export default App
