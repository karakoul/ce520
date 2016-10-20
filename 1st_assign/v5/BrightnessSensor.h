enum { AM_BRIGHTNESS = 3 };

typedef nx_struct BrightnessMessage {

	nx_uint16_t brightness;
	nx_uint16_t nodeId;

} Bright_Msg;