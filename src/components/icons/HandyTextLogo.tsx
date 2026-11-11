/** Dictovka wordmark (replaces the Handy logo). */
const HandyTextLogo = ({
  width,
  height,
  className,
}: {
  width?: number;
  height?: number;
  className?: string;
}) => {
  return (
    <svg
      width={width}
      height={height}
      className={className}
      viewBox="0 0 930 328"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      role="img"
      aria-label="Dictovka"
    >
      <text
        x="465"
        y="230"
        textAnchor="middle"
        className="logo-primary"
        fontFamily="-apple-system, BlinkMacSystemFont, 'SF Pro Rounded', 'Helvetica Neue', sans-serif"
        fontSize="210"
        fontWeight="700"
        letterSpacing="-4"
      >
        Dictovka
      </text>
    </svg>
  );
};

export default HandyTextLogo;
