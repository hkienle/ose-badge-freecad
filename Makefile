
# files to process
SRCS_OBS = obs-20210721-220641-flatpak-25-1920x1080.mkv
TARGETS_FFMPEG = ### $(addprefix ffmpeg-x264-crf23-,${SRCS_OBS})
TARGETS_FFMPEG += $(addprefix ffmpeg-x264-crf25-,${SRCS_OBS})
TARGETS_FFMPEG += ### $(addprefix ffmpeg-x264-abr2pass-,${SRCS_OBS})
TARGETS_FFMPEG += $(addprefix ffmpeg-x265-,${SRCS_OBS})
#TARGETS_FFMPEG += $(addprefix ffmpeg-av1-,${SRCS_OBS}) # very slow encoding

# https://ffmpeg.org/ffmpeg.html
#  -v: quiet error warning info
FFMPEG_FLAGS_COMMON= -y -v info -hide_banner -benchmark

# http://trac.ffmpeg.org/wiki/FFprobeTips
FFPROBE_FLAGS_COMMON= -v error -hide_banner -pretty
FFPROBE_FLAGS_OF= -of compact=nk=0:p=0

all : ${TARGETS_FFMPEG}

# @echo ${FFPROBE_FLAGS_OF}

# write text file with meta-information about video file
.SECONDARY:
%.txt : %.mkv
	@rm -f $@
	@echo $<  >> $@
	@echo -n "  " >> $@
	@ffprobe ${FFPROBE_FLAGS_COMMON} -show_format -show_entries format=nb_streams,duration,size,bit_rate \
		-of compact=nk=0:p=0 $<  >> $@
	@echo -n "  " >> $@
	@ffprobe ${FFPROBE_FLAGS_COMMON} -select_streams v -show_entries stream=codec_name,profile,level,bit_rate,avg_frame_rate,nb_frames \
		-of compact=nk=0:p=0 $<  >> $@
	@echo -n "  " >> $@
	@ffprobe ${FFPROBE_FLAGS_COMMON} -select_streams a -show_entries stream=codec_name,profile,sample_rate,bit_rate,avg_frame_rate \
		-of compact=nk=0:p=0 $<  >> $@
	@cat $@

# CRF
# https://slhck.info/ffmpeg-encoding-course/#/28
# https://slhck.info/video/2017/02/24/crf-guide.html
# "basically gives you constant quality throughout your encoding process"
# "use CRF encoding primarly for offline file storage"
# lower values is better quality, 0=lossless
# x264: crf= 18..23..28 (sane values)
# x265: crf= 0..28..51
ffmpeg-x264-crf23-%.mkv : %.mkv %.txt
	ffmpeg ${FFMPEG_FLAGS_COMMON} -i $< -codec:a copy -codec:v libx264 -crf 23 $@

ffmpeg-x264-crf25-%.mkv : %.mkv %.txt
	ffmpeg ${FFMPEG_FLAGS_COMMON} -i $< -codec:a copy -codec:v libx264 -crf 25 $@

ffmpeg-x265-%.mkv : %.mkv %.txt
	ffmpeg ${FFMPEG_FLAGS_COMMON} -i $< -codec:a copy -codec:v libx265 $@

# CRF
# https://trac.ffmpeg.org/wiki/Encode/AV1
# very slow encoding
ffmpeg-av1-%.mkv : %.mkv %.txt
	ffmpeg ${FFMPEG_FLAGS_COMMON} -i $< -codec:a copy -codec:v libaom-av1 -crf 30 -b:v 0 -strict experimental $@


# 2-Pass Average Bitrate (2-Pass ABR)
# https://slhck.info/ffmpeg-encoding-course/#/27
# https://slhck.info/video/2017/03/01/rate-control.html
# "easiest way to encode a file for streaming"
# "caveat: don’t know what the resulting quality will be, so you will have to do some tests"
# "caveat: there may be local spikes in bitrate, meaning you may send more than your client can receive"
# -b:v <bitrate> (1000K means 1000kbps)
ffmpeg-x264-abr2pass-%.mkv : %.mkv %.txt
	ffmpeg ${FFMPEG_FLAGS_COMMON} -i $< -codec:a copy -codec:v libx264 -b:v 1500K -pass 1 -f null /dev/null
	ffmpeg ${FFMPEG_FLAGS_COMMON} -i $< -codec:a copy -codec:v libx264 -b:v 1500K -pass 2 $@


clean :
	rm -rf *.txt *.log.mbtree *.log
	rm -rf ${TARGETS_FFMPEG}
