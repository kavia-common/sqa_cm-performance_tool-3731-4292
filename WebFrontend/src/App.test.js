import { render, screen } from "@testing-library/react";
import App from "./App";

test("renders dashboard brand", async () => {
  render(<App />);
  const brand = await screen.findByText(/SQA CM Performance Tool/i);
  expect(brand).toBeInTheDocument();
});
