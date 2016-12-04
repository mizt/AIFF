#import <Foundation/Foundation.h>
#import "aiff.h"

int main(int argc, char *argv[]) {
	
	@autoreleasepool {
		
		AIFF::Buffer *buffer = AIFF::read(DESKTOP_PATH(@"sample.aif"),2); // read Track3
		if(buffer->length<=0) return 0;
		
		long channels = 1;
		long length = buffer->length*channels;
		unsigned short *data = new unsigned short[length]{0};
		
		for(int k=0; k<buffer->length; k++) {
			data[k*channels+0] = AIFF::to(buffer->data[k]);
		}

		AIFF::write(DESKTOP_PATH(@"dst.aif"),data,length,channels);
		
	}
}