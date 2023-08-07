
all: pitch

pitch: pitch.c
	gcc -ggdb -o ./pitch.exe $^ -lfftw3 -lm

run:
	./pitch.exe mitrib.pcm out_ref.pcm
	cmp out_ref.pcm ../data/mitrib_pa8_2_2.pcm

clean:
	rm pitch.exe

