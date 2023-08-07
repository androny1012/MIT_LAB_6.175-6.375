import wave  
import numpy as np
def pcm2wav(pcm_file, wav_file, channels=1, bits=16, sample_rate=44100):
    # 打开 PCM 文件
    pcmf = open(pcm_file, 'rb')
    pcmdata = pcmf.read()
    pcmf.close()
 
    # 打开将要写入的 WAVE 文件
    wavfile = wave.open(wav_file, 'wb')
    # 设置声道数
    wavfile.setnchannels(channels)
    # 设置采样位宽
    wavfile.setsampwidth(bits // 8)
    # 设置采样率
    wavfile.setframerate(sample_rate)
    # 写入 data 部分
    wavfile.writeframes(pcmdata)

    pcmdata_np = np.array(pcmdata)
    print(pcmdata_np.dtype)
    
    wavfile.close()
 
pcm2wav("/home/anne/Bluespec/MIT/MyLab/6.375_Lab3/audio/ref/mitrib.pcm", "/home/anne/Bluespec/MIT/MyLab/6.375_Lab3/audio/ref/in.wav")
