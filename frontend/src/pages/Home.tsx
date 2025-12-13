import { useState, useEffect } from "react"
import { type Thread } from "../types/thread";

export const Home = () => {

  const [threads, setThreads] = useState<Thread[]>([]);

  useEffect(() => {
    const fetchThreads = async () => {
      try {
        const res = await fetch(`${import.meta.env.VITE_API_BASE_URL}/threads/all`);
        if (!res.ok) {
          console.error(`Failed to fetch threads: ${res.status} ${res.statusText}`);
          return;
        }
        const data = await res.json();
        setThreads(data.items);
      } catch (error) {
        console.error("An error occurred while fetching threads: ", error);
      }
    };

    fetchThreads();
  }, [])

  return (
    <div>
      <h1>Home</h1>
      <div>
        {threads.map((thread) => (
          <div key={thread.id}>
            <h2>{thread.title}</h2>
            <span>投稿者: {thread.authorName}</span>
            <p>{thread.body}</p>
            <hr />
          </div>
        ))}
      </div>
    </div>
  )
}
