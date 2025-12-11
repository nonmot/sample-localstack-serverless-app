import { useState, useEffect } from "react"

export const Home = () => {

  const [threads, setThreads] = useState([]);

  useEffect(() => {
    const fetchThreads = async () => {
      const res = await fetch(`${import.meta.env.VITE_API_BASE_URL}/threads/all`);
      const data = await res.json();
      console.log(data.items);
      setThreads(data.items)
    };

    fetchThreads();
  }, [])

  return (
    <div>
      <h1>Home</h1>
      <div>
        {threads.map((thread) => (
          <div key={thread.id}>
            <h2>{thread.id}</h2>
          </div>
        ))}
      </div>
    </div>
  )
}
