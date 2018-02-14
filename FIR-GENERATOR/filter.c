#include <stdio.h>
#include <math.h>
#define pi acos(-1)

double sinc(double x){
  return (x == 0) ? 1 : sin(pi*x)/(pi*x);
}	


int main(){ 
  FILE *file;
  file = fopen("fir.v", "w");
  
  int N, H , W, w_type;
  printf("Enter the order of the FIR Filter N: ");
  scanf("%d", &N);
  N = (N%2) ? N : N+1;
  printf("Enter the number of bits (H) of the FIR Filter coefficients h: ");
  scanf("%d", &H);
  printf("Enter the number of bits (W) of the input and output data: ");
  scanf("%d", &W);
  printf("Enter the window type"
         "\n0 for Rectangular Windowing"
	 "\n1 for Hamming Windowing: ");
  scanf("%d", &w_type);

  fprintf(file, "parameter N = %d;\n"
		"parameter W = %d;\n"
		"parameter H = %d;\n"
		 "\nmodule fir_filter(input clock,"
		 "\n\t\t  input signed [W-1:0] Xin,"
		 "\n\t\t  output reg signed [W-1:0] Y);\n\n\n"
		 "\treg signed [H:0] h[N];"
		 "\n\treg signed [W+H:0] y[N];\n\n\n", N, W, H);
  int m = (N-1)/2;
  int h, h_rect;
  double hamming;
  for(int i = 0; i < N; i++){	
    h_rect = pow(2,H)*0.5*sinc(0.5*(i-m));
    hamming = 0.54-0.46*cos(2*pi*i/(N-1));
    h = !w_type ? h_rect : h_rect*hamming;
    fprintf(file, "\tassign h[%d] = %d;\n", i, h);
  }
  fprintf(file, "\n\tassign Y = y[N-1]>>H;\n");
  fprintf(file, "\n\talways@ (posedge clock) begin\n"
		 "\t  y[0] <= h[0]*Xin;\n"
		 "\t  for(int i = 0; i < N; i++)\n"
		 "\t    y[i] <= y[i-1]+h[N-i-1]*Xin;"
		 "\n\tend");

  fprintf(file, "\n\nendmodule");
  fclose(file);
  return 0;
}
