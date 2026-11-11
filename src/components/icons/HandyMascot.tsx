/** Dictovka mascot: the blue microphone app icon (replaces the Handy hand). */
const HandyMascot = ({ className = "" }: { className?: string }) => {
  return (
    <svg
      viewBox="0 0 151 165"
      className={className}
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
    >
      <defs>
        <linearGradient id="dictovka-mascot-bg" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#4FA3FF" />
          <stop offset="1" stopColor="#1E5BE6" />
        </linearGradient>
      </defs>
      <rect x="8" y="15" width="135" height="135" rx="32" fill="url(#dictovka-mascot-bg)" />
      <rect x="60" y="36" width="31" height="54" rx="15.5" fill="#fff" />
      <path d="M45 72a30.5 30.5 0 0 0 61 0" stroke="#fff" strokeWidth="7" strokeLinecap="round" />
      <path d="M75.5 103v15M61 125h29" stroke="#fff" strokeWidth="7" strokeLinecap="round" />
    </svg>
  );
};

export default HandyMascot;
