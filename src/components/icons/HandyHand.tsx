/** Dictovka microphone glyph (replaces the Handy hand); follows the theme colour. */
const HandyHand = ({
  width,
  height,
}: {
  width?: number | string;
  height?: number | string;
  // The sidebar passes a className for its icons; the glyph ignores it.
  className?: string;
}) => (
  <svg
    width={width || 126}
    height={height || 135}
    viewBox="0 0 126 135"
    className="stroke-text"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <rect x="43" y="10" width="40" height="70" rx="20" className="fill-text" />
    <path d="M27 62a36 36 0 0 0 72 0" strokeWidth="9" strokeLinecap="round" />
    <path d="M63 98v19M44 122h38" strokeWidth="9" strokeLinecap="round" />
  </svg>
);

export default HandyHand;
