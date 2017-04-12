ffmpeg -r 5 -i Vel_Out%04d.jpg -vf scale=1928:948 -c:v libx264 -preset slow -r 30 -f mp4 video2.mp4
